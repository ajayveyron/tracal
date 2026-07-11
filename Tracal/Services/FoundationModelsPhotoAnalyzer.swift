#if TRACAL_ENABLE_ON_DEVICE_PHOTO_ANALYSIS
import CoreGraphics
import Foundation
import ImageIO

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Uses the iOS 27 on-device multimodal model for ordinary meal photos. The
/// result remains an editable estimate and never writes directly to storage.
public actor FoundationModelsPhotoAnalyzer {
    public init() {}

    public func availability() -> LocalModelAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
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
                return .unavailable(
                    reason: "On-device photo analysis is unavailable: \(String(describing: reason))."
                )
            }
        }
        #endif

        return .unsupportedOperatingSystem
    }

    public func analyze(
        _ image: SanitizedMealImage,
        hint: String?,
        loggedAt: Date,
        source: MealInputSource
    ) async throws -> AnalyzedMealDraft {
        let currentAvailability = availability()
        guard currentAvailability.isAvailable else {
            throw MealAnalysisError.localModelUnavailable(currentAvailability)
        }

        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return try await analyzeOnDevice(
                image,
                hint: hint,
                loggedAt: loggedAt,
                source: source
            )
        }
        #endif

        throw MealAnalysisError.localModelUnavailable(.unsupportedOperatingSystem)
    }
}

#if canImport(FoundationModels)
@available(iOS 27.0, *)
private extension FoundationModelsPhotoAnalyzer {
    func analyzeOnDevice(
        _ image: SanitizedMealImage,
        hint: String?,
        loggedAt: Date,
        source: MealInputSource
    ) async throws -> AnalyzedMealDraft {
        guard
            let imageSource = CGImageSourceCreateWithData(image.data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw MealAnalysisError.unreadableImage
        }

        let session = LanguageModelSession(instructions: Self.instructions)
        let cleanedHint = hint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await session.respond(
            generating: GeneratedMealDraft.self,
            options: GenerationOptions(samplingMode: .greedy)
        ) {
            "Analyze the visible food and drinks in this meal photo."
            if let cleanedHint, !cleanedHint.isEmpty {
                "The user added this context: \(cleanedHint)"
            }
            Attachment(cgImage).label("meal-photo")
        }

        return try FoundationModelsMealParser.makeDraft(
            from: response.content,
            loggedAt: loggedAt,
            source: source,
            analysisRoute: .onDeviceMultimodal,
            promptVersion: "nutrition-photo-v1"
        )
    }

    static let instructions = """
    You structure a private food log from one meal photo. Identify only visible
    foods and drinks. Estimate the entire consumed portion's calories, protein,
    carbohydrate, and fat grams. Do not give health advice. Do not imply that a
    photo reveals hidden ingredients. List uncertain portions, oil, sauces, and
    preparation in assumptions. Use confidence values from 0 to 1 and set
    needsReview to true whenever a portion or ingredient is estimated.
    """
}
#endif
#endif
