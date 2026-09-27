import Foundation

enum SharedSettings {
    static let appGroupID = "group.com.debrajpal.dally"
    static let rescheduleNotification = "com.debrajpal.dally.reschedule" as CFString

    static var isExtension: Bool {
        Bundle.main.bundleURL.pathExtension == "appex"
    }

    static var suite: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// The app reads its own defaults. The widget reads the mirrored app-group copy.
    static var defaults: UserDefaults {
        isExtension ? suite : .standard
    }

    static func mirrorFromAppDefaults() {
        guard !isExtension else { return }
        let keys = [
            AppStorageKey.notificationsMasterEnabled,
            AppStorageKey.quietHoursEnabled,
            AppStorageKey.quietHoursStartHour,
            AppStorageKey.quietHoursStartMinute,
            AppStorageKey.quietHoursEndHour,
            AppStorageKey.quietHoursEndMinute,
        ]
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                suite.set(value, forKey: key)
            }
        }
    }

    static func postReschedule() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rescheduleNotification),
            nil,
            nil,
            true
        )
    }
}
