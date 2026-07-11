import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Parses typed meal descriptions with Apple's on-device model. This service
/// never accepts images, performs network requests, or persists prompt text.
public actor FoundationModelsMealParser {
    public init() {}

    public func availability() -> LocalModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .deviceNotEligible
            case .unavailable(.appleIntelligenceNotEnabled):
                return .appleIntelligenceDisabled
            case .unavailable(.modelNotReady):
                return .modelNotReady
            case .unavailable(let reason):
                return .unavailable(reason: "Apple Intelligence is unavailable: \(String(describing: reason)).")
            @unknown default:
                return .unavailable(reason: "Apple Intelligence is temporarily unavailable.")
            }
        }
        #endif

        return .unsupportedOperatingSystem
    }

    public func parse(
        _ text: String,
        loggedAt: Date,
        source: MealInputSource
    ) async throws -> AnalyzedMealDraft {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw MealAnalysisError.emptyInput
        }

        let currentAvailability = availability()
        guard currentAvailability.isAvailable else {
            throw MealAnalysisError.localModelUnavailable(currentAvailability)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let session = LanguageModelSession(instructions: Self.instructions)
            let response = try await session.respond(
                to: Self.prompt(for: trimmedText),
                generating: GeneratedMealDraft.self
            )
            return try Self.makeDraft(
                from: response.content,
                loggedAt: loggedAt,
                source: source,
                analysisRoute: .onDeviceFoundationModel,
                promptVersion: "nutrition-text-v1"
            )
        }
        #endif

        throw MealAnalysisError.localModelUnavailable(.unsupportedOperatingSystem)
    }

    private static let instructions = """
    You structure a private food log. Identify only foods and drinks explicitly
    described by the user. Estimate the consumed portion's calories and protein,
    carbohydrate, and fat grams using ordinary nutrition knowledge. Do not give
    health advice. Keep uncertain ingredients in assumptions. Confidence values
    must be between 0 and 1. Nutrition values must be finite and nonnegative.
    The app validates and saves each usable result automatically. Preserve any
    uncertainty in the structured metadata.
    """

    private static func prompt(for text: String) -> String {
        """
        Convert this meal description into item-level nutrition. Nutrition for
        each item must represent the entire described quantity, not a per-100g
        value. Use a short meal title. If oil, sauce, serving size, or ingredients
        are unclear, set needsReview to true and state one concise uncertainty
        note in reviewReason.

        BEGIN USER MEAL
        \(text)
        END USER MEAL
        """
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GeneratedMealDraft {
    @Guide(description: "A short, plain title for the whole meal")
    var title: String

    @Guide(description: "True whenever any identity, ingredient, or portion is estimated")
    var needsReview: Bool

    @Guide(description: "One concise uncertainty note, or an empty string when none")
    var reviewReason: String

    @Guide(description: "Every distinct food or drink described by the user")
    var items: [GeneratedFoodItem]
}

@available(iOS 26.0, *)
@Generable
struct GeneratedFoodItem {
    @Guide(description: "Plain food or drink name")
    var name: String

    @Guide(description: "Consumed quantity as a positive number")
    var quantity: Double

    @Guide(description: "Short measurement such as serving, piece, cup, bowl, ml, or g")
    var unit: String

    @Guide(description: "Estimated consumed weight in grams, or zero when unknown")
    var estimatedGrams: Double

    @Guide(description: "Calories in the entire consumed quantity")
    var caloriesKcal: Double

    @Guide(description: "Protein grams in the entire consumed quantity")
    var proteinGrams: Double

    @Guide(description: "Carbohydrate grams in the entire consumed quantity")
    var carbohydrateGrams: Double

    @Guide(description: "Fat grams in the entire consumed quantity")
    var fatGrams: Double

    @Guide(description: "Food identity confidence from 0 to 1")
    var identificationConfidence: Double

    @Guide(description: "Portion confidence from 0 to 1")
    var portionConfidence: Double

    @Guide(description: "Uncertain portions, ingredients, oils, sauces, or preparation details")
    var assumptions: [String]
}

@available(iOS 26.0, *)
extension FoundationModelsMealParser {
    static func makeDraft(
        from generated: GeneratedMealDraft,
        loggedAt: Date,
        source: MealInputSource,
        analysisRoute: MealAnalysisRoute,
        promptVersion: String
    ) throws -> AnalyzedMealDraft {
        let items = generated.items.compactMap { generatedItem -> AnalyzedFoodItem? in
            let name = generatedItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let grams = generatedItem.estimatedGrams.finiteNonnegative
            return AnalyzedFoodItem(
                name: name,
                quantity: max(0.01, generatedItem.quantity.finiteNonnegative),
                unit: generatedItem.unit.trimmed(or: "serving"),
                estimatedGrams: grams > 0 ? grams : nil,
                nutrition: NutritionValues(
                    caloriesKcal: generatedItem.caloriesKcal,
                    proteinGrams: generatedItem.proteinGrams,
                    carbohydrateGrams: generatedItem.carbohydrateGrams,
                    fatGrams: generatedItem.fatGrams
                ).normalized,
                identificationConfidence: generatedItem.identificationConfidence.unitInterval,
                portionConfidence: generatedItem.portionConfidence.unitInterval,
                assumptions: generatedItem.assumptions
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        }

        guard !items.isEmpty else {
            throw MealAnalysisError.invalidModelResponse("No food items")
        }

        let lowConfidence = items.contains { item in
            (item.identificationConfidence ?? 0) < 0.7
                || (item.portionConfidence ?? 0) < 0.65
        }
        let reason = generated.reviewReason.trimmingCharacters(in: .whitespacesAndNewlines)

        return AnalyzedMealDraft(
            loggedAt: loggedAt,
            title: generated.title.trimmed(or: items.first?.name ?? "Meal"),
            inputSource: source,
            analysisRoute: analysisRoute,
            items: items,
            needsReview: generated.needsReview || lowConfidence,
            reviewReason: reason.isEmpty
                ? (lowConfidence ? "Check the estimated portion." : nil)
                : reason,
            promptVersion: promptVersion,
            modelVersion: "SystemLanguageModel.default"
        )
    }
}
#endif

private extension String {
    func trimmed(or fallback: String) -> String {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }
}

private extension Double {
    var finiteNonnegative: Double {
        guard isFinite else { return 0 }
        return max(0, self)
    }

    var unitInterval: Double {
        min(1, finiteNonnegative)
    }
}
