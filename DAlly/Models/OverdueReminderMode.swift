import Foundation

enum OverdueReminderMode: String, Codable, CaseIterable, Identifiable {
    case onceAfter10Minutes
    case everyHourUntilDone
    case off

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onceAfter10Minutes: "Once, 10 minutes later"
        case .everyHourUntilDone: "Every hour until done"
        case .off: "Off"
        }
    }

    var helper: String {
        switch self {
        case .onceAfter10Minutes: "One more ping after due."
        case .everyHourUntilDone: "Hourly until done or skipped."
        case .off: "Only the on-time ping."
        }
    }
}
