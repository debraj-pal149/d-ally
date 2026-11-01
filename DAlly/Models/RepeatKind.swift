import Foundation

enum RepeatKind: String, Codable, CaseIterable, Identifiable {
    case daily
    case everyNDays
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .everyNDays: "Every few days"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }
}

enum RepeatOption: Hashable, Identifiable {
    case daily
    case every2Days
    case every3Days
    case weekly
    case monthly
    case yearly

    var id: String {
        switch self {
        case .daily: "daily"
        case .every2Days: "every2"
        case .every3Days: "every3"
        case .weekly: "weekly"
        case .monthly: "monthly"
        case .yearly: "yearly"
        }
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .every2Days: "Every 2 days"
        case .every3Days: "Every 3 days"
        case .weekly: "Weekly"
        case .monthly: "Monthly, on this date"
        case .yearly: "Yearly, on this date"
        }
    }

    var kind: RepeatKind {
        switch self {
        case .daily: .daily
        case .every2Days, .every3Days: .everyNDays
        case .weekly: .weekly
        case .monthly: .monthly
        case .yearly: .yearly
        }
    }

    var intervalDays: Int {
        switch self {
        case .every3Days: 3
        default: 2
        }
    }

    static var pickerOptions: [RepeatOption] {
        [.daily, .every2Days, .every3Days, .weekly, .monthly, .yearly]
    }

    static func from(kind: RepeatKind, intervalDays: Int) -> RepeatOption {
        switch kind {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        case .everyNDays:
            return intervalDays >= 3 ? .every3Days : .every2Days
        }
    }
}

enum WeekdayChoice: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    static func bit(for weekday: Int) -> Int {
        1 << (weekday - 1)
    }
}

enum WeeklyWeekdays {
    static func contains(mask: Int, weekday: Int) -> Bool {
        guard (1...7).contains(weekday) else { return false }
        return mask & WeekdayChoice.bit(for: weekday) != 0
    }

    static func toggling(mask: Int, weekday: Int) -> Int {
        mask ^ WeekdayChoice.bit(for: weekday)
    }

    static func inserting(mask: Int, weekday: Int) -> Int {
        mask | WeekdayChoice.bit(for: weekday)
    }

    static func mask(for weekdays: [Int]) -> Int {
        weekdays.reduce(0) { $0 | WeekdayChoice.bit(for: $1) }
    }

    static func todayMask(now: Date = Date()) -> Int {
        let w = Calendar.current.component(.weekday, from: now)
        return WeekdayChoice.bit(for: w)
    }

    static func summary(mask: Int) -> String {
        let selected = WeekdayChoice.allCases.filter { contains(mask: mask, weekday: $0.rawValue) }
        if selected.isEmpty { return "No days" }
        if selected.count == 7 { return "Every day" }
        return selected.map(\.shortLabel).joined(separator: ", ")
    }
}

/// Monthly / yearly "on this date" matching, clamped to the last day of the month when needed.
enum RepeatDateMatch {
    static func monthly(day: Date, anchor: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = day.startOfLocalDay
        let start = anchor.startOfLocalDay
        guard dayStart >= start else { return false }
        let wanted = calendar.component(.day, from: start)
        return calendar.component(.day, from: dayStart) == clampedDay(wanted, inSameMonthAs: dayStart, calendar: calendar)
    }

    static func yearly(day: Date, anchor: Date, calendar: Calendar = .current) -> Bool {
        let dayStart = day.startOfLocalDay
        let start = anchor.startOfLocalDay
        guard dayStart >= start else { return false }
        guard calendar.component(.month, from: dayStart) == calendar.component(.month, from: start) else {
            return false
        }
        let wanted = calendar.component(.day, from: start)
        return calendar.component(.day, from: dayStart) == clampedDay(wanted, inSameMonthAs: dayStart, calendar: calendar)
    }

    static func clampedDay(_ day: Int, inSameMonthAs date: Date, calendar: Calendar = .current) -> Int {
        let range = calendar.range(of: .day, in: .month, for: date) ?? 1..<32
        return min(max(day, 1), range.count)
    }

    static func monthlyCaption(anchor: Date, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: anchor.startOfLocalDay)
        return "Every month on the \(dayOrdinal(day))"
    }

    static func yearlyCaption(anchor: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("dMMM")
        return "Every year on \(formatter.string(from: anchor.startOfLocalDay))"
    }

    private static func dayOrdinal(_ day: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        formatter.locale = .current
        return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }
}
