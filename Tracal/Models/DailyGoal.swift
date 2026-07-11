import Foundation
import SwiftData

@Model
final class DailyGoal {
    var id: UUID
    var effectiveDate: Date
    var calorieTarget: Double
    var proteinTargetG: Double?
    var carbohydrateTargetG: Double?
    var fatTargetG: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        effectiveDate: Date = .now,
        calorieTarget: Double,
        proteinTargetG: Double? = nil,
        carbohydrateTargetG: Double? = nil,
        fatTargetG: Double? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.effectiveDate = Calendar.current.startOfDay(for: effectiveDate)
        self.calorieTarget = max(0, calorieTarget)
        self.proteinTargetG = proteinTargetG.map { max(0, $0) }
        self.carbohydrateTargetG = carbohydrateTargetG.map { max(0, $0) }
        self.fatTargetG = fatTargetG.map { max(0, $0) }
        self.createdAt = createdAt
    }
}

extension Collection where Element == DailyGoal {
    func effectiveGoal(on date: Date, calendar: Calendar = .current) -> DailyGoal? {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return filter { $0.effectiveDate < endOfDay }
            .max { $0.effectiveDate < $1.effectiveDate }
    }
}

