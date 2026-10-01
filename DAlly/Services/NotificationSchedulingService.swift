import Foundation
import SwiftData
import UserNotifications

struct DesiredNotification: Equatable {
    var identifier: String
    var fire: Date
    var taskId: UUID
    var taskName: String
    var schedule: ScheduleKind
    var windowEndHour: Int
    var windowEndMinute: Int
    var dayKey: String
    var kind: String
}

/// Builds and replaces the rolling local-notification window.
/// Store reads stay on the main actor with a live ModelContext. Overlapping
/// calls coalesce so a short-lived context cannot wipe a good schedule.
@MainActor
final class NotificationSchedulingService {
    static let shared = NotificationSchedulingService()
    private init() {}

    private var generation = 0
    private var inFlight: Task<Void, Never>?

    /// Safe from any thread. Always opens its own store context on the main actor.
    nonisolated func rescheduleFromStore(context: ModelContext? = nil) {
        // The optional context is ignored on purpose: callers such as AppDelegate
        // used to pass a ModelContext that died before async work ran, which
        // produced an empty plan and deleted every pending habit alert.
        _ = context
        Task { @MainActor in
            self.enqueueReschedule()
        }
    }

    func rescheduleAll(tasks: [DailyTask], logs: [TaskDayLog], now: Date = Date()) async {
        let plan = buildPlan(tasks: tasks, logs: logs, now: now)
        await apply(plan)
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
            taskId: task.id,
            taskName: task.name,
            schedule: task.schedule,
            windowEndHour: task.windowEndHour,
            windowEndMinute: task.windowEndMinute,
            dayKey: day.localDayKey,
            kind: "overdueHourly"
        )
        await add(item)
    }

    func notifications(for task: DailyTask, day: Date, dayKey: String, now: Date) -> [DesiredNotification] {
        var result: [DesiredNotification] = []
        let nudge = task.nudgeDate(on: day)
        let due = task.dueDate(on: day)
        let base = DesiredNotification(
            identifier: "",
            fire: now,
            taskId: task.id,
            taskName: task.name,
            schedule: task.schedule,
            windowEndHour: task.windowEndHour,
            windowEndMinute: task.windowEndMinute,
            dayKey: dayKey,
            kind: ""
        )

        if nudge > now {
            var item = base
            item.identifier = NotificationIDs.ontime(taskId: task.id, dayKey: dayKey)
            item.fire = nudge
            item.kind = "ontime"
            result.append(item)
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
                var item = base
                item.identifier = NotificationIDs.overdueOnce(taskId: task.id, dayKey: dayKey)
                item.fire = candidate
                item.kind = "overdueOnce"
                result.append(item)
            }
        case .everyHourUntilDone:
            var fire = due.addingTimeInterval(3600)
            let dayEnd = day.endOfLocalDay
            while fire <= dayEnd {
                if fire > now && !QuietHoursService.isInQuietHours(at: fire) {
                    var item = base
                    item.identifier = NotificationIDs.overdueHourly(taskId: task.id, dayKey: dayKey, fire: fire)
                    item.fire = fire
                    item.kind = "overdueHourly"
                    result.append(item)
                }
                fire = fire.addingTimeInterval(3600)
            }
        case .off:
            break
        }

        return result
    }

    /// Next Sunday at 12:00 local. If today is Sunday and noon is still ahead, use today.
    nonisolated static func nextSundayNoon(after now: Date = Date()) -> Date? {
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

    // MARK: - Private

    private func enqueueReschedule() {
        generation += 1
        let gen = generation
        inFlight?.cancel()
        inFlight = Task { @MainActor in
            // Coalesce the burst from launch / become-active / widget / sync.
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard !Task.isCancelled, gen == self.generation else { return }

            let store = ModelContext(Persistence.shared)
            let tasks = (try? store.fetch(FetchDescriptor<DailyTask>())) ?? []
            let logs = (try? store.fetch(FetchDescriptor<TaskDayLog>())) ?? []
            let plan = self.buildPlan(tasks: tasks, logs: logs, now: Date())
            guard !Task.isCancelled, gen == self.generation else { return }
            await self.apply(plan)
        }
    }

    private struct Plan {
        var masterOn: Bool
        var desired: [DesiredNotification]
    }

    private func buildPlan(tasks: [DailyTask], logs: [TaskDayLog], now: Date) -> Plan {
        let masterOn = UserDefaults.standard.object(forKey: AppStorageKey.notificationsMasterEnabled) as? Bool
            ?? AppDefaults.notificationsMasterEnabled

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
        // Leave one slot for the weekly review ping.
        if desired.count > 63 {
            desired = Array(desired.prefix(63))
        }

        return Plan(masterOn: masterOn, desired: desired)
    }

    private func apply(_ plan: Plan) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral

        let center = UNUserNotificationCenter.current()

        if !plan.masterOn || !authorized {
            center.removeAllPendingNotificationRequests()
            return
        }

        var keep = Set(plan.desired.map(\.identifier))
        keep.insert(NotificationIDs.weeklyReview)
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { !keep.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        for item in plan.desired {
            await add(item)
        }
        await scheduleWeeklyReview()
    }

    /// Repeats every Sunday at 12:00 local. A one-shot date was wiped whenever the app rescheduled.
    private func scheduleWeeklyReview() async {
        var comps = DateComponents()
        comps.weekday = Calendar.sundayWeekday
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
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
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIDs.weeklyReview,
            content: content,
            trigger: trigger
        )
        do {
            // Replace any prior weekly request so a bad one cannot linger.
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [NotificationIDs.weeklyReview]
            )
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Best-effort: try once more without the remove, in case of a timing race.
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    private func add(_ item: DesiredNotification) async {
        let content = UNMutableNotificationContent()
        content.title = item.taskName
        content.sound = .default
        content.categoryIdentifier = NotificationIDs.categoryReminder
        content.interruptionLevel = .active
        content.body = body(for: item)
        content.userInfo = [
            "url": "dally://day?date=\(item.dayKey)&taskId=\(item.taskId.uuidString)&prompt=1",
            "taskId": item.taskId.uuidString,
            "dayKey": item.dayKey,
            "kind": item.kind
        ]

        var comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: item.fire
        )
        comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func body(for item: DesiredNotification) -> String {
        switch item.kind {
        case "ontime":
            if item.schedule == .flexibleUntil {
                let completeBy = TimeDisplay.clock(hour: item.windowEndHour, minute: item.windowEndMinute)
                return AppCopy.notifDueBy(completeBy)
            }
            return AppCopy.notifItsTime(taskName: item.taskName)
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
