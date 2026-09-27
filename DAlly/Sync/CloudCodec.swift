import Foundation

/// Cloud shape of a habit. Days travel as "yyyy-MM-dd" so a phone in another
/// time zone lands on the same calendar day.
struct CloudHabit: Equatable {
    var id: UUID
    var name: String
    var notes: String
    var scheduleKind: String
    var hour: Int
    var minute: Int
    var windowEndHour: Int
    var windowEndMinute: Int
    var priority: String
    var colorHex: String
    var markPattern: String
    var startDay: String
    var endDay: String?
    var isStopped: Bool
    var overdueReminderMode: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var notificationsEnabled: Bool
    var repeatKind: String
    var repeatIntervalDays: Int
    var weeklyWeekdaysMask: Int
    var deletedAt: Date?
}

struct CloudLog: Equatable {
    var taskId: UUID
    var dayKey: String
    var status: String
    var resolvedAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}

enum CloudCodec {
    static let schemaVersion = 1

    static func habit(from task: DailyTask) -> [String: Any] {
        var data: [String: Any] = [
            "id": task.id.uuidString,
            "name": task.name,
            "notes": task.notes,
            "scheduleKind": task.scheduleKind,
            "hour": task.hour,
            "minute": task.minute,
            "windowEndHour": task.windowEndHour,
            "windowEndMinute": task.windowEndMinute,
            "priority": task.priority,
            "colorHex": task.colorHex,
            "markPattern": task.markPattern,
            "startDay": task.startDate.localDayKey,
            "isStopped": task.isStopped,
            "overdueReminderMode": task.overdueReminderMode,
            "createdAt": task.createdAt,
            "updatedAt": task.updatedAt,
            "sortOrder": task.sortOrder,
            "notificationsEnabled": task.notificationsEnabled,
            "repeatKind": task.repeatKind,
            "repeatIntervalDays": task.repeatIntervalDays,
            "weeklyWeekdaysMask": task.weeklyWeekdaysMask,
            "schema": schemaVersion,
        ]
        if let end = task.endDate {
            data["endDay"] = end.localDayKey
        }
        return data
    }

    static func habitTombstone(id: UUID, deletedAt: Date) -> [String: Any] {
        [
            "id": id.uuidString,
            "deletedAt": deletedAt,
            "updatedAt": deletedAt,
            "schema": schemaVersion,
        ]
    }

    static func log(from log: TaskDayLog) -> [String: Any] {
        [
            "taskId": log.taskId.uuidString,
            "dayKey": log.dayKey,
            "status": log.status,
            "resolvedAt": log.resolvedAt,
            "updatedAt": log.updatedAt,
            "schema": schemaVersion,
        ]
    }

    static func logTombstone(taskId: UUID, dayKey: String, deletedAt: Date) -> [String: Any] {
        [
            "taskId": taskId.uuidString,
            "dayKey": dayKey,
            "deletedAt": deletedAt,
            "updatedAt": deletedAt,
            "schema": schemaVersion,
        ]
    }

    static func decodeHabit(_ data: [String: Any]) -> CloudHabit? {
        guard let idString = data["id"] as? String, let id = UUID(uuidString: idString),
              let updatedAt = date(data["updatedAt"]) else { return nil }
        let deletedAt = date(data["deletedAt"])
        if deletedAt != nil {
            return CloudHabit(
                id: id, name: "", notes: "", scheduleKind: ScheduleKind.fixedTime.rawValue, hour: 9, minute: 0,
                windowEndHour: 0, windowEndMinute: 0, priority: PriorityLevel.normal.rawValue, colorHex: "#2CD4FF",
                markPattern: MarkPattern.solid.rawValue, startDay: "", endDay: nil, isStopped: true,
                overdueReminderMode: OverdueReminderMode.onceAfter10Minutes.rawValue, createdAt: updatedAt,
                updatedAt: updatedAt, sortOrder: 0, notificationsEnabled: false, repeatKind: RepeatKind.daily.rawValue,
                repeatIntervalDays: 2, weeklyWeekdaysMask: 0, deletedAt: deletedAt
            )
        }
        guard let name = data["name"] as? String, let startDay = data["startDay"] as? String else { return nil }
        return CloudHabit(
            id: id,
            name: name,
            notes: data["notes"] as? String ?? "",
            scheduleKind: data["scheduleKind"] as? String ?? ScheduleKind.fixedTime.rawValue,
            hour: int(data["hour"]) ?? 9,
            minute: int(data["minute"]) ?? 0,
            windowEndHour: int(data["windowEndHour"]) ?? 0,
            windowEndMinute: int(data["windowEndMinute"]) ?? 0,
            priority: data["priority"] as? String ?? PriorityLevel.normal.rawValue,
            colorHex: data["colorHex"] as? String ?? "#2CD4FF",
            markPattern: data["markPattern"] as? String ?? MarkPattern.solid.rawValue,
            startDay: startDay,
            endDay: data["endDay"] as? String,
            isStopped: data["isStopped"] as? Bool ?? false,
            overdueReminderMode: data["overdueReminderMode"] as? String ?? OverdueReminderMode.onceAfter10Minutes.rawValue,
            createdAt: date(data["createdAt"]) ?? updatedAt,
            updatedAt: updatedAt,
            sortOrder: int(data["sortOrder"]) ?? 0,
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
            repeatKind: data["repeatKind"] as? String ?? RepeatKind.daily.rawValue,
            repeatIntervalDays: int(data["repeatIntervalDays"]) ?? 2,
            weeklyWeekdaysMask: int(data["weeklyWeekdaysMask"]) ?? 0,
            deletedAt: nil
        )
    }

    static func decodeLog(_ data: [String: Any]) -> CloudLog? {
        guard let idString = data["taskId"] as? String, let taskId = UUID(uuidString: idString),
              let dayKey = data["dayKey"] as? String,
              let updatedAt = date(data["updatedAt"]) else { return nil }
        return CloudLog(
            taskId: taskId,
            dayKey: dayKey,
            status: data["status"] as? String ?? DayLogStatus.kept.rawValue,
            resolvedAt: date(data["resolvedAt"]) ?? updatedAt,
            updatedAt: updatedAt,
            deletedAt: date(data["deletedAt"])
        )
    }

    /// Writes cloud fields onto a local habit. `updatedAt` follows the cloud value so the
    /// record does not look newer than the copy it came from.
    static func apply(_ cloud: CloudHabit, to task: DailyTask) {
        task.name = cloud.name
        task.notes = cloud.notes
        task.scheduleKind = cloud.scheduleKind
        task.hour = cloud.hour
        task.minute = cloud.minute
        task.windowEndHour = cloud.windowEndHour
        task.windowEndMinute = cloud.windowEndMinute
        task.priority = cloud.priority
        task.colorHex = cloud.colorHex
        task.markPattern = cloud.markPattern
        task.startDate = Date.date(fromDayKey: cloud.startDay)?.startOfLocalDay ?? task.startDate
        task.endDate = cloud.endDay.flatMap(Date.date(fromDayKey:))?.startOfLocalDay
        task.isStopped = cloud.isStopped
        task.overdueReminderMode = cloud.overdueReminderMode
        task.createdAt = cloud.createdAt
        task.updatedAt = cloud.updatedAt
        task.sortOrder = cloud.sortOrder
        task.notificationsEnabled = cloud.notificationsEnabled
        task.repeatKind = cloud.repeatKind
        task.repeatIntervalDays = cloud.repeatIntervalDays
        task.weeklyWeekdaysMask = cloud.weeklyWeekdaysMask
    }

    static func makeTask(from cloud: CloudHabit) -> DailyTask {
        let task = DailyTask(id: cloud.id, name: cloud.name, colorHex: cloud.colorHex)
        apply(cloud, to: task)
        return task
    }

    private static func date(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        if let seconds = value as? TimeInterval { return Date(timeIntervalSince1970: seconds) }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

/// Who wins when the same record changed in two places. Latest change wins; a tie keeps
/// what is already on this phone, so nothing flips back and forth.
enum SyncMerge {
    enum Decision: Equatable {
        case applyRemote
        case keepLocal
    }

    static func decide(localUpdatedAt: Date?, localPendingAt: Date?, remoteUpdatedAt: Date) -> Decision {
        let localMarks = [localUpdatedAt, localPendingAt].compactMap { $0 }
        guard let newestLocal = localMarks.max() else { return .applyRemote }
        return remoteUpdatedAt > newestLocal ? .applyRemote : .keepLocal
    }

    static func shouldPush(localChangedAt: Date, remoteUpdatedAt: Date?) -> Bool {
        guard let remote = remoteUpdatedAt else { return true }
        return localChangedAt >= remote
    }
}
