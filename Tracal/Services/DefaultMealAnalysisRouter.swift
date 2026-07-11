import Foundation

/// Keeps deterministic facts local, then calls only the provider explicitly
/// selected by the user. Foundation Models remains a text-only offline
/// fallback; no request silently crosses to another cloud provider.
public actor DefaultMealAnalysisRouter: MealAnalysisRouting {
    private let deterministic: DeterministicMealParser
    private let foundationModels: FoundationModelsMealParser
    private let vision: VisionNutritionLabelOCRService
    private let provider: any DirectProviderAnalyzing

    public init() {
        deterministic = DeterministicMealParser()
        foundationModels = FoundationModelsMealParser()
        vision = VisionNutritionLabelOCRService()
        provider = DirectProviderService()
    }

    init(
        deterministic: DeterministicMealParser = DeterministicMealParser(),
        foundationModels: FoundationModelsMealParser = FoundationModelsMealParser(),
        vision: VisionNutritionLabelOCRService = VisionNutritionLabelOCRService(),
        provider: any DirectProviderAnalyzing = DirectProviderService()
    ) {
        self.deterministic = deterministic
        self.foundationModels = foundationModels
        self.vision = vision
        self.provider = provider
    }

    public func localModelAvailability() async -> LocalModelAvailability {
        await foundationModels.availability()
    }

    public func analyze(_ request: MealAnalysisRequest) async throws -> AnalyzedMealDraft {
        try Task.checkCancellation()

        let draft: AnalyzedMealDraft
        switch request.input {
        case .text(let text):
            draft = try await analyzeText(text, request: request)

        case .photo(let image, _):
            draft = try await analyzePhoto(image, request: request)
        }

        return try validated(draft, request: request)
    }

    private func analyzeText(
        _ text: String,
        request: MealAnalysisRequest
    ) async throws -> AnalyzedMealDraft {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { throw MealAnalysisError.emptyInput }

        if let explicitDraft = deterministic.parseExplicitText(
            trimmedText,
            loggedAt: request.loggedAt,
            source: request.source
        ) {
            return explicitDraft
        }

        let providerFailure: MealAnalysisError
        do {
            return try await provider.analyze(request)
        } catch is CancellationError {
            throw MealAnalysisError.cancelled
        } catch let error as MealAnalysisError {
            providerFailure = error
        } catch {
            providerFailure = .providerUnavailable(
                AIProviderPreferences().activeProvider,
                .networkUnavailable
            )
        }

        do {
            return try await foundationModels.parse(
                trimmedText,
                loggedAt: request.loggedAt,
                source: request.source
            )
        } catch is CancellationError {
            throw MealAnalysisError.cancelled
        } catch {
            throw providerFailure
        }
    }

    private func analyzePhoto(
        _ image: SanitizedMealImage,
        request: MealAnalysisRequest
    ) async throws -> AnalyzedMealDraft {
        do {
            let recognition = try await vision.recognizeText(in: image.data)
            if let labelDraft = deterministic.parseNutritionLabel(
                recognition,
                loggedAt: request.loggedAt,
                source: request.source
            ) {
                return labelDraft
            }
        } catch is CancellationError {
            throw MealAnalysisError.cancelled
        } catch {
            // A normal meal photo often has no useful text. Continue to the
            // selected multimodal provider without treating failed OCR as a user error.
        }

        do {
            return try await provider.analyze(request)
        } catch is CancellationError {
            throw MealAnalysisError.cancelled
        } catch let error as MealAnalysisError {
            throw error
        } catch {
            throw MealAnalysisError.providerUnavailable(
                AIProviderPreferences().activeProvider,
                .networkUnavailable
            )
        }
    }

    private func validated(
        _ draft: AnalyzedMealDraft,
        request: MealAnalysisRequest
    ) throws -> AnalyzedMealDraft {
        guard !draft.items.isEmpty else {
            throw MealAnalysisError.invalidModelResponse("No items")
        }

        var normalized = draft
        normalized.id = request.id
        normalized.loggedAt = request.loggedAt
        normalized.inputSource = request.source
        normalized.originalDescription = originalDescription(from: request)
        normalized.protectedImagePath = request.protectedImagePath
        normalized.title = normalized.title
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.title.isEmpty {
            normalized.title = normalized.items.first?.name ?? "Meal"
        }

        normalized.items = normalized.items.map { item in
            var value = item
            value.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            value.unit = item.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            value.nutrition = item.nutrition.normalized
            value.quantity = item.quantity.isFinite ? max(0.01, item.quantity) : 1
            if let grams = item.estimatedGrams {
                value.estimatedGrams = grams.isFinite && grams > 0 ? grams : nil
            }
            return value
        }

        let totals = normalized.totals
        guard
            totals.isValid,
            totals.caloriesKcal <= 50_000,
            totals.proteinGrams <= 5_000,
            totals.carbohydrateGrams <= 5_000,
            totals.fatGrams <= 5_000
        else {
            throw MealAnalysisError.invalidModelResponse("Implausible nutrition values")
        }

        return normalized
    }

    private func originalDescription(from request: MealAnalysisRequest) -> String? {
        switch request.input {
        case .text(let text):
            return text
        case .photo(_, let hint):
            return hint
        }
    }
}
