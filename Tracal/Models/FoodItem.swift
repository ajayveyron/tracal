import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var amount: Double
    var unit: String
    var estimatedGrams: Double?
    var caloriesKcal: Double
    var proteinG: Double
    var carbohydrateG: Double
    var fatG: Double
    var identificationConfidence: Double? = nil
    var portionConfidence: Double? = nil
    var assumptions: [String]
    var wasCorrected: Bool
    var meal: MealEntry?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Double = 1,
        unit: String = "serving",
        estimatedGrams: Double? = nil,
        caloriesKcal: Double,
        proteinG: Double = 0,
        carbohydrateG: Double = 0,
        fatG: Double = 0,
        identificationConfidence: Double? = nil,
        portionConfidence: Double? = nil,
        assumptions: [String] = [],
        wasCorrected: Bool = false,
        meal: MealEntry? = nil
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.amount = max(0, amount)
        self.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        self.estimatedGrams = estimatedGrams.map { max(0, $0) }
        self.caloriesKcal = max(0, caloriesKcal)
        self.proteinG = max(0, proteinG)
        self.carbohydrateG = max(0, carbohydrateG)
        self.fatG = max(0, fatG)
        self.identificationConfidence = identificationConfidence.map { min(max($0, 0), 1) }
        self.portionConfidence = portionConfidence.map { min(max($0, 0), 1) }
        self.assumptions = assumptions
        self.wasCorrected = wasCorrected
        self.meal = meal
    }

    var nutrition: NutritionSnapshot {
        NutritionSnapshot(
            caloriesKcal: caloriesKcal,
            proteinG: proteinG,
            carbohydrateG: carbohydrateG,
            fatG: fatG
        )
    }
}
