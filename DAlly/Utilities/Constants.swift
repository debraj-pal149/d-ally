import Foundation

enum AppStorageKey {
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let appearanceMode = "appearanceMode"
    static let notificationsMasterEnabled = "notificationsMasterEnabled"
    static let hasRequestedNotificationPermission = "hasRequestedNotificationPermission"
    static let defaultOverdueMode = "defaultOverdueMode"
    static let quietHoursEnabled = "quietHoursEnabled"
    static let quietHoursStartHour = "quietHoursStartHour"
    static let quietHoursStartMinute = "quietHoursStartMinute"
    static let quietHoursEndHour = "quietHoursEndHour"
    static let quietHoursEndMinute = "quietHoursEndMinute"
}

enum AppDefaults {
    static let appearanceMode = AppearanceMode.system.rawValue
    static let notificationsMasterEnabled = true
    static let defaultOverdueMode = OverdueReminderMode.onceAfter10Minutes.rawValue
    static let quietHoursEnabled = true
    static let quietHoursStartHour = 22
    static let quietHoursStartMinute = 0
    static let quietHoursEndHour = 7
    static let quietHoursEndMinute = 0
    static let notesMaxLength = 2000
}

enum NotificationIDs {
    static let categoryReminder = "dally.reminder"
    static let categoryWeekly = "dally.weekly"
    static let actionDone = "dally.action.done"
    static let actionSkip = "dally.action.skip"
    static let actionOpen = "dally.action.open"
    static let bgRefresh = "com.dally.app.refresh"
    static let weeklyReview = "weekly.review"

    static func ontime(taskId: UUID, dayKey: String) -> String {
        "ontime.\(taskId.uuidString).\(dayKey)"
    }

    static func overdueOnce(taskId: UUID, dayKey: String) -> String {
        "overdue10.\(taskId.uuidString).\(dayKey)"
    }

    static func overdueHourly(taskId: UUID, dayKey: String, fire: Date) -> String {
        let stamp = Self.hourlyStamp.string(from: fire)
        return "overdueHourly.\(taskId.uuidString).\(dayKey).\(stamp)"
    }

    static func matches(taskId: UUID, dayKey: String, identifier: String) -> Bool {
        identifier.contains(".\(taskId.uuidString).\(dayKey)")
    }

    static func parseTaskAndDay(from identifier: String) -> (UUID, String)? {
        let parts = identifier.split(separator: ".").map(String.init)
        // ontime.UUID.dayKey  OR overdue10.UUID.dayKey OR overdueHourly.UUID.dayKey.stamp
        guard parts.count >= 3, let id = UUID(uuidString: parts[1]) else { return nil }
        return (id, parts[2])
    }

    private static let hourlyStamp: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMddHHmm"
        return f
    }()
}

enum AppCopy {
    static let brand = "d·ally"
    static let tagline = "Daily consistency."
    static let welcomeBody = "Show up every day."
    static let point1 = "You pick a time. It repeats daily."
    static let point2 = "Done sits above what is next."
    static let point3 = "Kept days show as color on the calendar."
    static let begin = "Start"
    static let alreadyKnow = "Skip"
    static let emptyHeadline = "Start a daily rhythm."
    static let emptyBody = "Tap + to add one."
    static let addDailyReminder = "Add reminder"
    static let jumpToToday = "Back to today"
    static let calendarLegend = "Color = kept. Ring = skipped. Blank = open."
    static let primingTitle = "Allow alerts?"
    static let primingBody = "You get a ping at the time you set."
    static let enableAlerts = "Allow"
    static let notNow = "Not now"
    static let deleteTitle = "Delete this reminder?"
    static let deleteBody = "Deletes the reminder and its history."
    static let stopTitle = "Stop this reminder?"
    static let stopBody = "No more alerts. History stays."
    static let futureResolve = "Wait until that day."
    static let quietHelper = "Uses phone time. On-time alerts still sound."
    static let quietInvalid = "Start and end cannot match."
    static let settingsAlertsBlurb = "d·ally notifications help you stick to your daily rhythm."
    static let weekReviewBannerTitle = "Review your week"
    static let weekReviewBannerBody = "See which days you kept on the calendar."
    static let weekReviewBannerCTA = "Open calendar"
    static let weekReviewNotifTitle = "Your week at d·ally"
    static let weekReviewNotifBody = "Consistency is a pattern. Glance at the calendar."
    static let notifStillOpen = "This one's still open for today."

    static func notifItsTime(taskName: String) -> String {
        "It's time to do \(taskName)."
    }

    static func notifDueBy(_ time: String) -> String {
        "Due by \(time)."
    }
}
