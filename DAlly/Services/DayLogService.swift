import Foundation
import SwiftData
import WidgetKit

enum DayLogService {
    static func log(for taskId: UUID, day: Date, logs: [TaskDayLog]) -> TaskDayLog? {
        let key = day.startOfLocalDay.localDayKey
        return logs.first { $0.taskId == taskId && $0.dayKey == key }
    }

    static func status(taskId: UUID, day: Date, logs: [TaskDayLog]) -> DayLogStatus? {
        log(for: taskId, day: day, logs: logs)?.dayLogStatus
    }

    @discardableResult
    static func upsert(
        taskId: UUID,
        day: Date,
        status: DayLogStatus,
        at resolvedAt: Date = Date(),
        in context: ModelContext
    ) -> TaskDayLog {
        let key = day.startOfLocalDay.localDayKey
        let now = Date()
        let row: TaskDayLog
        if let existing = fetchLog(taskId: taskId, dayKey: key, in: context) {
            existing.dayLogStatus = status
            existing.resolvedAt = resolvedAt
            existing.updatedAt = now
            row = existing
        } else {
            row = TaskDayLog(taskId: taskId, dayKey: key, status: status, resolvedAt: resolvedAt, updatedAt: now)
            context.insert(row)
        }
        try? context.save()
        SyncRecorder.logChanged(taskId: taskId, dayKey: key, at: now, in: context)
        refreshAfterChange(context: context)
        return row
    }

    static func markKept(taskId: UUID, day: Date, at date: Date = Date(), in context: ModelContext) {
        upsert(taskId: taskId, day: day.startOfLocalDay, status: .kept, at: date, in: context)
    }

    static func markSkipped(taskId: UUID, day: Date, at date: Date = Date(), in context: ModelContext) {
        upsert(taskId: taskId, day: day.startOfLocalDay, status: .skipped, at: date, in: context)
    }

    static func clearLog(taskId: UUID, day: Date, in context: ModelContext) {
        let key = day.startOfLocalDay.localDayKey
        if let existing = fetchLog(taskId: taskId, dayKey: key, in: context) {
            context.delete(existing)
            try? context.save()
            SyncRecorder.logDeleted(taskId: taskId, dayKey: key, in: context)
            refreshAfterChange(context: context)
        }
    }

    static func deleteLogs(for taskId: UUID, in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<TaskDayLog>())) ?? []
        let now = Date()
        for log in all where log.taskId == taskId {
            let dayKey = log.dayKey
            context.delete(log)
            SyncRecorder.logDeleted(taskId: taskId, dayKey: dayKey, at: now, in: context)
        }
        try? context.save()
    }

    static func keptLogsGroupedByDay(logs: [TaskDayLog]) -> [String: [TaskDayLog]] {
        Dictionary(grouping: logs.filter { $0.dayLogStatus == .kept }, by: \.dayKey)
    }

    static func fetchLog(taskId: UUID, dayKey: String, in context: ModelContext) -> TaskDayLog? {
        let all = (try? context.fetch(FetchDescriptor<TaskDayLog>())) ?? []
        return all.first { $0.taskId == taskId && $0.dayKey == dayKey }
    }

    /// Widgets and alerts follow every change. The widget process cannot touch the app's
    /// notification center, so it asks the app to reschedule instead.
    static func refreshAfterChange(context: ModelContext) {
        WidgetCenter.shared.reloadAllTimelines()
        if SharedSettings.isExtension {
            SharedSettings.postReschedule()
        } else {
            SharedSettings.mirrorFromAppDefaults()
            NotificationSchedulingService.shared.rescheduleFromStore(context: context)
        }
    }
}
