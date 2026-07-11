import Foundation

/// Nutrition for one complete food item or meal.
///
/// Values deliberately use the same units as nutrition labels and the shared
/// analysis contract. All aggregate values are derived by adding these values;
/// callers should not persist a second total.
public struct Nutrition: Codable, Hashable, Sendable {
    public var caloriesKcal: Double
    public var proteinG: Double
    public var carbohydratesG: Double
    public var fatG: Double
    public var fiberG: Double
    public var sugarG: Double
    public var sodiumMg: Double

    public init(
        caloriesKcal: Double = 0,
        proteinG: Double = 0,
        carbohydratesG: Double = 0,
        fatG: Double = 0,
        fiberG: Double = 0,
        sugarG: Double = 0,
        sodiumMg: Double = 0
    ) {
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.carbohydratesG = carbohydratesG
        self.fatG = fatG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
    }

    public static let zero = Nutrition()

    public static func + (lhs: Nutrition, rhs: Nutrition) -> Nutrition {
        Nutrition(
            caloriesKcal: lhs.caloriesKcal + rhs.caloriesKcal,
            proteinG: lhs.proteinG + rhs.proteinG,
            carbohydratesG: lhs.carbohydratesG + rhs.carbohydratesG,
            fatG: lhs.fatG + rhs.fatG,
            fiberG: lhs.fiberG + rhs.fiberG,
            sugarG: lhs.sugarG + rhs.sugarG,
            sodiumMg: lhs.sodiumMg + rhs.sodiumMg
        )
    }

    public static func += (lhs: inout Nutrition, rhs: Nutrition) {
        lhs = lhs + rhs
    }

    public func scaled(by multiplier: Double) -> Nutrition {
        Nutrition(
            caloriesKcal: caloriesKcal * multiplier,
            proteinG: proteinG * multiplier,
            carbohydratesG: carbohydratesG * multiplier,
            fatG: fatG * multiplier,
            fiberG: fiberG * multiplier,
            sugarG: sugarG * multiplier,
            sodiumMg: sodiumMg * multiplier
        )
    }

    public static func total<S: Sequence>(of values: S) -> Nutrition where S.Element == Nutrition {
        values.reduce(.zero, +)
    }
}

public struct DailyGoal: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var effectiveDate: Date
    public var caloriesKcal: Double
    public var proteinG: Double?
    public var carbohydratesG: Double?
    public var fatG: Double?

    public init(
        id: UUID = UUID(),
        effectiveDate: Date,
        caloriesKcal: Double,
        proteinG: Double? = nil,
        carbohydratesG: Double? = nil,
        fatG: Double? = nil
    ) {
        self.id = id
        self.effectiveDate = effectiveDate
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.carbohydratesG = carbohydratesG
        self.fatG = fatG
    }
}

/// Progress for a nutrient. `remaining` is signed so the UI can distinguish a
/// true overage; `remainingClamped` is convenient for progress rings.
public struct NutrientProgress: Codable, Hashable, Sendable {
    public var consumed: Double
    public var target: Double?

    public init(consumed: Double, target: Double?) {
        self.consumed = consumed
        self.target = target
    }

    public var remaining: Double? {
        target.map { $0 - consumed }
    }

    public var remainingClamped: Double? {
        remaining.map { max(0, $0) }
    }

    public var overage: Double? {
        target.map { max(0, consumed - $0) }
    }

    public var fractionConsumed: Double? {
        guard let target, target > 0 else { return nil }
        return consumed / target
    }
}

public struct NutritionBalance: Codable, Hashable, Sendable {
    public var calories: NutrientProgress
    public var protein: NutrientProgress
    public var carbohydrates: NutrientProgress
    public var fat: NutrientProgress

    public init(consumed: Nutrition, goal: DailyGoal?) {
        calories = NutrientProgress(consumed: consumed.caloriesKcal, target: goal?.caloriesKcal)
        protein = NutrientProgress(consumed: consumed.proteinG, target: goal?.proteinG)
        carbohydrates = NutrientProgress(consumed: consumed.carbohydratesG, target: goal?.carbohydratesG)
        fat = NutrientProgress(consumed: consumed.fatG, target: goal?.fatG)
    }
}
