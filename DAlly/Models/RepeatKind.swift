import Foundation

enum RepeatKind: String, Codable, CaseIterable, Identifiable {
    case daily
    case everyNDays
    case weekly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: "Daily"
        case .everyNDays: "Every few days"
        case .weekly: "Weekly"
        }
    }
}

enum RepeatOption: Hashable, Identifiable {
    case daily
    case every2Days
    case every3Days
    case weekly

    var id: String {
        switch self {
        case .daily: "daily"
        case .every2Days: "every2"
        case .every3Days: "every3"
        case .weekly: "weekly"
        }
    }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .every2Days: "Every 2 days"
        case .every3Days: "Every 3 days"
        case .weekly: "Weekly"
        }
    }

    var kind: RepeatKind {
        switch self {
        case .daily: .daily
        case .every2Days, .every3Days: .everyNDays
        case .weekly: .weekly
        }
    }

    var intervalDays: Int {
        switch self {
        case .every3Days: 3
        default: 2
        }
    }

    static func from(kind: RepeatKind, intervalDays: Int) -> RepeatOption {
        switch kind {
        case .daily: return .daily
        case .weekly: return .weekly
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
