import Foundation
import SwiftData
import UserNotifications

struct DesiredNotification: Equatable {
    var identifier: String
    var fire: Date
    var task: DailyTask
    var dayKey: String
    var kind: String
}

final class NotificationSchedulingService {
    static let shared = NotificationSchedulingService()
    private init() {}

    func rescheduleFromStore(context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<DailyTask>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<TaskDayLog>())) ?? []
        Task { await rescheduleAll(tasks: tasks, logs: logs) }
    }

    func rescheduleAll(tasks: [DailyTask], logs: [TaskDayLog], now: Date = Date()) async {
        let masterOn = UserDefaults.standard.object(forKey: AppStorageKey.notificationsMasterEnabled) as? Bool ?? true
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional

        if !masterOn || !authorized {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        var desired: [DesiredNotification] = []
        for offset in 0...6 {
            let day = now.addingLocalDays(offset)
            let dayKey = day.localDayKey
            let active = TaskOccurrenceService.tasks(for: day, allTasks: tasks)
            for task in active {
                if DayLogService.status(taskId: task.id, day: day, logs: logs) != nil { continue }
                if !task.notificationsEnabled { continue }
                desired.append(contentsOf: notifications(for: task, day: day, dayKey: dayKey, now: now))
            }
        }

        desired.sort { $0.fire < $1.fire }
        // Leave room for the weekly review ping (always scheduled separately).
        if desired.count > 63 {
            desired = Array(desired.prefix(63))
        }

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        for item in desired {
            await add(item)
        }
        await scheduleWeeklyReview(now: now)
    }

    func scheduleKeepReminding(task: DailyTask, day: Date, from now: Date = Date()) async {
        var fire = now.addingTimeInterval(3600)
        if QuietHoursService.isInQuietHours(at: fire) {
            fire = QuietHoursService.nextQuietEnd(after: fire)
        }
        guard fire > now else { return }
        let item = DesiredNotification(
            identifier: "keep.\(task.id.uuidString).\(day.localDayKey)",
            fire: fire,
            task: task,
            dayKey: day.localDayKey,
            kind: "overdueHourly"
        )
        await add(item)
    }

    func notifications(for task: DailyTask, day: Date, dayKey: String, now: Date) -> [DesiredNotification] {
        var result: [DesiredNotification] = []
        let nudge = task.nudgeDate(on: day)
        let due = task.dueDate(on: day)

        if nudge > now {
            result.append(DesiredNotification(
                identifier: NotificationIDs.ontime(taskId: task.id, dayKey: dayKey),
                fire: nudge,
                task: task,
                dayKey: dayKey,
                kind: "ontime"
            ))
        }

        guard task.overdueMode != .off else { return result }

        switch task.overdueMode {
        case .onceAfter10Minutes:
            var candidate = due.addingTimeInterval(10 * 60)
            // If the natural +10m fire fell inside quiet hours (even if that moment is already past),
            // defer to quiet end so the user still gets one follow-up (plan §5A.2 / §13).
            if QuietHoursService.isInQuietHours(at: candidate) {
                candidate = QuietHoursService.nextQuietEnd(after: candidate)
            }
            if candidate > now {
                result.append(DesiredNotification(
                    identifier: NotificationIDs.overdueOnce(taskId: task.id, dayKey: dayKey),
                    fire: candidate,
                    task: task,
                    dayKey: dayKey,
                    kind: "overdueOnce"
                ))
            }
        case .everyHourUntilDone:
            var fire = due.addingTimeInterval(3600)
            let dayEnd = day.endOfLocalDay
            while fire <= dayEnd {
                if fire > now && !QuietHoursService.isInQuietHours(at: fire) {
                    result.append(DesiredNotification(
                        identifier: NotificationIDs.overdueHourly(taskId: task.id, dayKey: dayKey, fire: fire),
                        fire: fire,
                        task: task,
                        dayKey: dayKey,
                        kind: "overdueHourly"
                    ))
                }
                fire = fire.addingTimeInterval(3600)
            }
        case .off:
            break
        }

        return result
    }

    /// Next Sunday at 12:00 local. If today is Sunday and noon is still ahead, use today.
    static func nextSundayNoon(after now: Date = Date()) -> Date? {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now) // 1 = Sunday
        var daysAhead = (Calendar.sundayWeekday - weekday + 7) % 7
        if daysAhead == 0 {
            if let noonToday = cal.date(bySettingHour: 12, minute: 0, second: 0, of: now), noonToday > now {
                return noonToday
            }
            daysAhead = 7
        }
        let sunday = now.addingLocalDays(daysAhead)
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: sunday)
    }

    private func scheduleWeeklyReview(now: Date) async {
        guard let fire = Self.nextSundayNoon(after: now), fire > now else { return }
        let content = UNMutableNotificationContent()
        content.title = AppCopy.weekReviewNotifTitle
        content.body = AppCopy.weekReviewNotifBody
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.categoryWeekly
        content.interruptionLevel = .active
        content.userInfo = [
            "url": "dally://calendar",
            "kind": "weeklyReview"
        ]
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIDs.weeklyReview,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func add(_ item: DesiredNotification) async {
        let content = UNMutableNotificationContent()
        content.title = item.task.name
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.categoryReminder
        content.interruptionLevel = .active
        content.body = body(for: item)
        content.userInfo = [
            "url": "dally://day?date=\(item.dayKey)&taskId=\(item.task.id.uuidString)&prompt=1",
            "taskId": item.task.id.uuidString,
            "dayKey": item.dayKey,
            "kind": item.kind
        ]

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fire)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func body(for item: DesiredNotification) -> String {
        switch item.kind {
        case "ontime":
            if item.task.schedule == .flexibleUntil {
                let completeBy = TimeDisplay.clock(hour: item.task.windowEndHour, minute: item.task.windowEndMinute)
                return AppCopy.notifDueBy(completeBy)
            }
            return AppCopy.notifItsTime(taskName: item.task.name)
        case "overdueOnce", "overdueHourly":
            return AppCopy.notifStillOpen
        default:
            return AppCopy.notifStillOpen
        }
    }
}

private extension Calendar {
    /// Gregorian: Sunday == 1
    static let sundayWeekday = 1
}
