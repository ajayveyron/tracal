import Foundation

/// A calendar-relative day key. Construct it with the user's calendar so meals
/// around midnight group according to the device time zone rather than UTC.
public struct LocalDay: Codable, Hashable, Comparable, Identifiable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    public var id: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func date(in calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    public func interval(in calendar: Calendar = .current) -> DateInterval? {
        guard let start = date(in: calendar),
              let end = calendar.date(byAdding: .day, value: 1, to: start)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// Half-open membership check (`start <= date < nextDay`) suitable for
    /// database predicates and day filtering.
    public func contains(_ date: Date, in calendar: Calendar = .current) -> Bool {
        guard let interval = interval(in: calendar) else { return false }
        return date >= interval.start && date < interval.end
    }

    public static func < (lhs: LocalDay, rhs: LocalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public struct MealDayGroup: Codable, Hashable, Identifiable, Sendable {
    public var day: LocalDay
    public var entries: [MealEntry]

    public init(day: LocalDay, entries: [MealEntry]) {
        self.day = day
        self.entries = entries
    }

    public var id: LocalDay { day }

    public var totals: Nutrition {
        Nutrition.total(of: entries.lazy.map(\.totals))
    }
}

public enum MealDayGrouping {
    /// Groups newest days first and newest meals first inside each day.
    public static func groups(
        for entries: [MealEntry],
        calendar: Calendar = .current
    ) -> [MealDayGroup] {
        Dictionary(grouping: entries) { LocalDay($0.loggedAt, calendar: calendar) }
            .map { day, dayEntries in
                MealDayGroup(
                    day: day,
                    entries: dayEntries.sorted {
                        if $0.loggedAt == $1.loggedAt { return $0.id.uuidString < $1.id.uuidString }
                        return $0.loggedAt > $1.loggedAt
                    }
                )
            }
            .sorted { $0.day > $1.day }
    }

    public static func entries(
        on day: LocalDay,
        from entries: [MealEntry],
        calendar: Calendar = .current
    ) -> [MealEntry] {
        entries
            .filter { LocalDay($0.loggedAt, calendar: calendar) == day }
            .sorted {
                if $0.loggedAt == $1.loggedAt { return $0.id.uuidString < $1.id.uuidString }
                return $0.loggedAt > $1.loggedAt
            }
    }

    public static func totals(
        on day: LocalDay,
        from entries: [MealEntry],
        calendar: Calendar = .current
    ) -> Nutrition {
        Nutrition.total(of: self.entries(on: day, from: entries, calendar: calendar).lazy.map(\.totals))
    }
}

public enum DailyGoalResolver {
    /// Returns the most recent goal effective on or before the requested day.
    public static func goal(
        for day: LocalDay,
        from goals: [DailyGoal],
        calendar: Calendar = .current
    ) -> DailyGoal? {
        guard let dayStart = day.date(in: calendar) else { return nil }
        return goals
            .filter { calendar.startOfDay(for: $0.effectiveDate) <= dayStart }
            .max {
                let lhs = calendar.startOfDay(for: $0.effectiveDate)
                let rhs = calendar.startOfDay(for: $1.effectiveDate)
                if lhs == rhs { return $0.id.uuidString < $1.id.uuidString }
                return lhs < rhs
            }
    }
}

public extension Date {
    func localDay(in calendar: Calendar = .current) -> LocalDay {
        LocalDay(self, calendar: calendar)
    }
}
