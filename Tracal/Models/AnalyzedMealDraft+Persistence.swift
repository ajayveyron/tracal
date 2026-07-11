import Foundation

extension MealEntry {
    convenience init(confirmedDraft draft: AnalyzedMealDraft) {
        let totals = draft.totals.normalized
        let persistedItems = draft.items.map {
            FoodItem(
                id: $0.id,
                name: $0.name,
                amount: $0.quantity,
                unit: $0.unit,
                estimatedGrams: $0.estimatedGrams,
                caloriesKcal: $0.nutrition.caloriesKcal,
                proteinG: $0.nutrition.proteinGrams,
                carbohydrateG: $0.nutrition.carbohydrateGrams,
                fatG: $0.nutrition.fatGrams,
                identificationConfidence: $0.identificationConfidence,
                portionConfidence: $0.portionConfidence,
                assumptions: $0.assumptions
            )
        }

        self.init(
            id: draft.id,
            loggedAt: draft.loggedAt,
            inputSource: StoredMealInputSource(draft.inputSource),
            analysisRoute: StoredMealAnalysisRoute(draft.analysisRoute),
            state: .confirmed,
            title: draft.title,
            caloriesKcal: totals.caloriesKcal,
            proteinG: totals.proteinGrams,
            carbohydrateG: totals.carbohydrateGrams,
            fatG: totals.fatGrams,
            confidence: Self.meanConfidence(for: draft.items),
            thumbnailRelativePath: draft.protectedImagePath,
            reviewReason: draft.reviewReason,
            promptVersion: draft.promptVersion,
            modelVersion: draft.modelVersion,
            originalDescription: draft.originalDescription,
            items: persistedItems
        )
    }

    private static func meanConfidence(for items: [AnalyzedFoodItem]) -> Double? {
        let values = items.flatMap { [$0.identificationConfidence, $0.portionConfidence].compactMap { $0 } }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

private extension StoredMealInputSource {
    init(_ source: MealInputSource) {
        switch source {
        case .typedText: self = .typed
        case .manual: self = .manual
        case .cameraPhoto: self = .camera
        case .photoLibrary: self = .photoLibrary
        }
    }
}

private extension StoredMealAnalysisRoute {
    init(_ route: MealAnalysisRoute) {
        switch route {
        case .manual: self = .manual
        case .deterministic: self = .personalMemory
        case .onDeviceFoundationModel: self = .appleIntelligence
        case .onDeviceMultimodal: self = .appleIntelligencePhoto
        case .visionNutritionLabel: self = .visionLabel
        case .openAI: self = .openAI
        case .anthropic: self = .anthropic
        case .gemini: self = .gemini
        case .vertexFallback: self = .vertexFallback
        }
    }
}
