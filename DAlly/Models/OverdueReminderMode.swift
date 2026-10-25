import Foundation

enum OverdueReminderMode: String, Codable, CaseIterable, Identifiable {
    case onceAfter30Minutes
    case everyHourUntilDone
    case every3HoursUntilDone
    case off

    /// Retired raw value still present in local stores / Firestore.
    private static let legacyOnceAfter10Minutes = "onceAfter10Minutes"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onceAfter30Minutes: "Once, 30 minutes later"
        case .everyHourUntilDone: "Every 1 hour until done"
        case .every3HoursUntilDone: "Every 3 hours until done"
        case .off: "Off"
        }
    }

    var helper: String {
        switch self {
        case .onceAfter30Minutes: "One more ping 30 minutes after due."
        case .everyHourUntilDone: "Every hour until done or skipped."
        case .every3HoursUntilDone: "Every 3 hours until done or skipped."
        case .off: "Only the on-time ping."
        }
    }

    /// Seconds between follow-ups for repeating modes. Nil for once / off.
    var repeatInterval: TimeInterval? {
        switch self {
        case .everyHourUntilDone: 3600
        case .every3HoursUntilDone: 3 * 3600
        case .onceAfter30Minutes, .off: nil
        }
    }

    /// Delay after due for the single follow-up. Nil when not a once-mode.
    var onceDelay: TimeInterval? {
        switch self {
        case .onceAfter30Minutes: 30 * 60
        case .everyHourUntilDone, .every3HoursUntilDone, .off: nil
        }
    }

    /// Resolves live and legacy stored strings (e.g. `onceAfter10Minutes` → 30 minutes).
    static func resolved(from raw: String?) -> OverdueReminderMode {
        guard let raw, !raw.isEmpty else { return .onceAfter30Minutes }
        if raw == legacyOnceAfter10Minutes { return .onceAfter30Minutes }
        return OverdueReminderMode(rawValue: raw) ?? .onceAfter30Minutes
    }

    /// Canonical string for new writes / sync (migrates legacy 10-minute value).
    static func normalizedRawValue(_ raw: String?) -> String {
        resolved(from: raw).rawValue
    }
}
