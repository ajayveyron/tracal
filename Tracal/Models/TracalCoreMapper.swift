import Foundation
import TracalCore

extension NutritionSnapshot {
    var coreValue: TracalCore.Nutrition {
        TracalCore.Nutrition(
            caloriesKcal: caloriesKcal,
            proteinG: proteinG,
            carbohydratesG: carbohydrateG,
            fatG: fatG
        )
    }
}

extension DailyGoal {
    var coreValue: TracalCore.DailyGoal {
        TracalCore.DailyGoal(
            id: id,
            effectiveDate: effectiveDate,
            caloriesKcal: calorieTarget,
            proteinG: proteinTargetG,
            carbohydratesG: carbohydrateTargetG,
            fatG: fatTargetG
        )
    }
}

extension FoodItem {
    var coreValue: TracalCore.MealItem {
        let mappedUnit = mappedPortionUnit
        return TracalCore.MealItem(
            id: id,
            name: name,
            quantity: amount,
            unit: mappedUnit.unit,
            customUnit: mappedUnit.customUnit,
            estimatedGrams: estimatedGrams,
            nutrition: nutrition.coreValue,
            assumptions: assumptions
        )
    }

    private var mappedPortionUnit: (unit: TracalCore.PortionUnit, customUnit: String?) {
        let normalized = unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch normalized {
        case "g", "gram", "grams":
            return (.gram, nil)
        case "ml", "milliliter", "milliliters":
            return (.milliliter, nil)
        case "tbsp", "tablespoon", "tablespoons":
            return (.tablespoon, nil)
        case "tsp", "teaspoon", "teaspoons":
            return (.teaspoon, nil)
        default:
            if let unit = TracalCore.PortionUnit(rawValue: normalized) {
                return (unit, nil)
            } else {
                return (.custom, self.unit)
            }
        }
    }
}

extension MealEntry {
    var coreValue: TracalCore.MealEntry {
        TracalCore.MealEntry(
            id: id,
            loggedAt: loggedAt,
            confirmedAt: updatedAt,
            source: inputSource.coreValue,
            analysisRoute: analysisRoute.coreValue,
            title: title,
            items: items.map(\.coreValue),
            confidence: confidence,
            thumbnailPath: thumbnailRelativePath
        )
    }
}

private extension StoredMealInputSource {
    var coreValue: TracalCore.MealSource {
        switch self {
        case .manual: .manual
        case .typed: .typedText
        case .camera: .cameraPhoto
        case .photoLibrary: .photoLibrary
        }
    }
}

private extension StoredMealAnalysisRoute {
    var coreValue: TracalCore.AnalysisRoute {
        switch self {
        case .manual: .manual
        case .personalMemory: .personalMatch
        case .appleIntelligence: .onDeviceText
        case .appleIntelligencePhoto: .onDeviceMultimodal
        case .visionLabel: .visionOCR
        case .openAI: .openAI
        case .anthropic: .anthropic
        case .gemini: .gemini
        case .vertexFallback: .vertexFallback
        }
    }
}
