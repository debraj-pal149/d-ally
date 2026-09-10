import Foundation

enum QuietHoursService {
    static func current() -> QuietHours {
        let d = UserDefaults.standard
        return QuietHours(
            enabled: d.object(forKey: AppStorageKey.quietHoursEnabled) as? Bool ?? AppDefaults.quietHoursEnabled,
            startHour: d.object(forKey: AppStorageKey.quietHoursStartHour) as? Int ?? AppDefaults.quietHoursStartHour,
            startMinute: d.object(forKey: AppStorageKey.quietHoursStartMinute) as? Int ?? AppDefaults.quietHoursStartMinute,
            endHour: d.object(forKey: AppStorageKey.quietHoursEndHour) as? Int ?? AppDefaults.quietHoursEndHour,
            endMinute: d.object(forKey: AppStorageKey.quietHoursEndMinute) as? Int ?? AppDefaults.quietHoursEndMinute
        )
    }

    static func isInQuietHours(at date: Date) -> Bool {
        current().isInQuietHours(at: date)
    }

    static func nextQuietEnd(after date: Date) -> Date {
        current().nextQuietEnd(after: date)
    }
}
