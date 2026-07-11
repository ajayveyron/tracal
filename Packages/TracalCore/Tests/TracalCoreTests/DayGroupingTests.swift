import Foundation
import Testing
@testable import TracalCore

@Suite("Calendar-day utilities")
struct DayGroupingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }

    @Test("LocalDay uses the injected time zone")
    func localDayUsesInjectedTimeZone() {
        let instant = Date(timeIntervalSince1970: 1_735_672_500) // 2024-12-31 21:55 UTC
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!

        #expect(LocalDay(instant, calendar: utc) == LocalDay(year: 2024, month: 12, day: 31))
        #expect(LocalDay(instant, calendar: calendar) == LocalDay(year: 2025, month: 1, day: 1))
    }

    @Test("Groups and entries sort newest first and derive totals")
    func groupsAndTotalsAreNewestFirst() {
        let first = entry(at: date(2025, 1, 1, 8), calories: 100)
        let second = entry(at: date(2025, 1, 1, 20), calories: 250)
        let third = entry(at: date(2025, 1, 2, 9), calories: 400)

        let groups = MealDayGrouping.groups(for: [first, third, second], calendar: calendar)

        #expect(groups.map(\.day) == [
            LocalDay(year: 2025, month: 1, day: 2),
            LocalDay(year: 2025, month: 1, day: 1),
        ])
        #expect(groups[1].entries.map(\.loggedAt) == [second.loggedAt, first.loggedAt])
        #expect(groups[1].totals.caloriesKcal == 350)
    }

    @Test("Goal resolution uses the latest effective goal")
    func goalResolverUsesLatestEffectiveGoal() {
        let old = DailyGoal(effectiveDate: date(2025, 1, 1), caloriesKcal: 2_000)
        let current = DailyGoal(effectiveDate: date(2025, 1, 10), caloriesKcal: 1_800)
        let future = DailyGoal(effectiveDate: date(2025, 2, 1), caloriesKcal: 1_700)

        let result = DailyGoalResolver.goal(
            for: LocalDay(year: 2025, month: 1, day: 15),
            from: [future, old, current],
            calendar: calendar
        )

        #expect(result?.id == current.id)
    }

    @Test("A LocalDay creates a half-open calendar interval")
    func localDayInterval() throws {
        let day = LocalDay(year: 2025, month: 7, day: 11)
        let interval = try #require(day.interval(in: calendar))

        #expect(interval.start == date(2025, 7, 11))
        #expect(interval.end == date(2025, 7, 12))
        #expect(day.contains(date(2025, 7, 11, 23), in: calendar))
        let containsEnd = day.contains(interval.end, in: calendar)
        #expect(containsEnd == false)
    }

    private func entry(at date: Date, calories: Double) -> MealEntry {
        MealEntry(
            loggedAt: date,
            source: .manual,
            analysisRoute: .manual,
            title: "Meal",
            items: [
                MealItem(
                    name: "Food",
                    quantity: 1,
                    unit: .serving,
                    nutrition: Nutrition(caloriesKcal: calories)
                ),
            ]
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
