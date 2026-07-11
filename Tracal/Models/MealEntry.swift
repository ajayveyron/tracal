import Foundation
import SwiftData

enum StoredMealInputSource: String, Codable, CaseIterable {
    case manual
    case typed
    case camera
    case photoLibrary

    var label: String {
        switch self {
        case .manual: "Manual"
        case .typed: "Typed"
        case .camera: "Camera"
        case .photoLibrary: "Photo"
        }
    }

    var systemImage: String {
        switch self {
        case .manual: "square.and.pencil"
        case .typed: "text.cursor"
        case .camera: "camera.fill"
        case .photoLibrary: "photo.fill"
        }
    }
}

enum StoredMealAnalysisRoute: String, Codable, CaseIterable {
    case manual
    case personalMemory
    case appleIntelligence
    case appleIntelligencePhoto
    case visionLabel
    case vertexFallback
}

enum StoredMealEntryState: String, Codable, CaseIterable {
    case draft
    case pending
    case needsReview
    case confirmed
    case failed
}

@Model
final class MealEntry {
    var id: UUID
    var loggedAt: Date
    var inputSourceRawValue: String
    var analysisRouteRawValue: String
    var stateRawValue: String
    var title: String
    var caloriesKcal: Double
    var proteinG: Double
    var carbohydrateG: Double
    var fatG: Double
    var confidence: Double?
    var thumbnailRelativePath: String?
    var reviewReason: String? = nil
    var promptVersion: String? = nil
    var modelVersion: String? = nil
    var originalDescription: String? = nil
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.meal)
    var items: [FoodItem]

    init(
        id: UUID = UUID(),
        loggedAt: Date = .now,
        inputSource: StoredMealInputSource = .manual,
        analysisRoute: StoredMealAnalysisRoute = .manual,
        state: StoredMealEntryState = .confirmed,
        title: String,
        caloriesKcal: Double,
        proteinG: Double = 0,
        carbohydrateG: Double = 0,
        fatG: Double = 0,
        confidence: Double? = nil,
        thumbnailRelativePath: String? = nil,
        reviewReason: String? = nil,
        promptVersion: String? = nil,
        modelVersion: String? = nil,
        originalDescription: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        items: [FoodItem] = []
    ) {
        self.id = id
        self.loggedAt = loggedAt
        self.inputSourceRawValue = inputSource.rawValue
        self.analysisRouteRawValue = analysisRoute.rawValue
        self.stateRawValue = state.rawValue
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.caloriesKcal = max(0, caloriesKcal)
        self.proteinG = max(0, proteinG)
        self.carbohydrateG = max(0, carbohydrateG)
        self.fatG = max(0, fatG)
        self.confidence = confidence.map { min(max($0, 0), 1) }
        self.thumbnailRelativePath = thumbnailRelativePath
        self.reviewReason = reviewReason
        self.promptVersion = promptVersion
        self.modelVersion = modelVersion
        self.originalDescription = originalDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.items = items
    }

    var inputSource: StoredMealInputSource {
        get { StoredMealInputSource(rawValue: inputSourceRawValue) ?? .manual }
        set { inputSourceRawValue = newValue.rawValue }
    }

    var analysisRoute: StoredMealAnalysisRoute {
        get { StoredMealAnalysisRoute(rawValue: analysisRouteRawValue) ?? .manual }
        set { analysisRouteRawValue = newValue.rawValue }
    }

    var state: StoredMealEntryState {
        get { StoredMealEntryState(rawValue: stateRawValue) ?? .draft }
        set { stateRawValue = newValue.rawValue }
    }

    var nutrition: NutritionSnapshot {
        NutritionSnapshot(
            caloriesKcal: caloriesKcal,
            proteinG: proteinG,
            carbohydrateG: carbohydrateG,
            fatG: fatG
        )
    }

    func updateTotalsFromItems() {
        let total = items.reduce(.zero) { $0 + $1.nutrition }
        caloriesKcal = total.caloriesKcal
        proteinG = total.proteinG
        carbohydrateG = total.carbohydrateG
        fatG = total.fatG
        updatedAt = .now
    }

    func duplicate(at date: Date = .now) -> MealEntry {
        let copiedItems = items.map {
            FoodItem(
                name: $0.name,
                amount: $0.amount,
                unit: $0.unit,
                estimatedGrams: $0.estimatedGrams,
                caloriesKcal: $0.caloriesKcal,
                proteinG: $0.proteinG,
                carbohydrateG: $0.carbohydrateG,
                fatG: $0.fatG,
                identificationConfidence: $0.identificationConfidence,
                portionConfidence: $0.portionConfidence,
                assumptions: $0.assumptions,
                wasCorrected: $0.wasCorrected
            )
        }

        return MealEntry(
            loggedAt: date,
            inputSource: inputSource,
            analysisRoute: .personalMemory,
            state: .confirmed,
            title: title,
            caloriesKcal: caloriesKcal,
            proteinG: proteinG,
            carbohydrateG: carbohydrateG,
            fatG: fatG,
            confidence: confidence,
            thumbnailRelativePath: thumbnailRelativePath,
            reviewReason: reviewReason,
            promptVersion: promptVersion,
            modelVersion: modelVersion,
            originalDescription: originalDescription,
            items: copiedItems
        )
    }
}
