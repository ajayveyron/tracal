import Foundation

struct NutritionSnapshot: Hashable, Sendable {
    var caloriesKcal: Double
    var proteinG: Double
    var carbohydrateG: Double
    var fatG: Double

    static let zero = NutritionSnapshot(
        caloriesKcal: 0,
        proteinG: 0,
        carbohydrateG: 0,
        fatG: 0
    )

    static func + (lhs: Self, rhs: Self) -> Self {
        NutritionSnapshot(
            caloriesKcal: lhs.caloriesKcal + rhs.caloriesKcal,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbohydrateG: lhs.carbohydrateG + rhs.carbohydrateG,
            fatG: lhs.fatG + rhs.fatG
        )
    }
}

struct DailyNutritionSummary: Hashable, Sendable {
    let consumed: NutritionSnapshot
    let calorieTarget: Double?
    let proteinTargetG: Double?
    let carbohydrateTargetG: Double?
    let fatTargetG: Double?

    init(entries: [MealEntry], goal: DailyGoal?) {
        consumed = entries
            .filter { $0.state == .confirmed }
            .reduce(.zero) { $0 + $1.nutrition }
        calorieTarget = goal?.calorieTarget
        proteinTargetG = goal?.proteinTargetG
        carbohydrateTargetG = goal?.carbohydrateTargetG
        fatTargetG = goal?.fatTargetG
    }

    var caloriesRemaining: Double? {
        calorieTarget.map { $0 - consumed.caloriesKcal }
    }

    var calorieProgress: Double {
        guard let calorieTarget, calorieTarget > 0 else { return 0 }
        return min(max(consumed.caloriesKcal / calorieTarget, 0), 1)
    }
}

extension Collection where Element == MealEntry {
    func entries(on date: Date, calendar: Calendar = .current) -> [MealEntry] {
        filter { calendar.isDate($0.loggedAt, inSameDayAs: date) }
    }
}

