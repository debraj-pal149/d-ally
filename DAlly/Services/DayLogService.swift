import Foundation
import SwiftData
import WidgetKit

enum DayLogService {
    /// App wires this to Mixpanel; widget leaves it nil.
    nonisolated(unsafe) static var onAnalytics: ((String, String, Date) -> Void)?

    static func log(for taskId: UUID, day: Date, logs: [TaskDayLog]) -> TaskDayLog? {
        let key = day.startOfLocalDay.localDayKey
        return logs.first { $0.taskId == taskId && $0.dayKey == key }
    }

    static func status(taskId: UUID, day: Date, logs: [TaskDayLog]) -> DayLogStatus? {
        log(for: taskId, day: day, logs: logs)?.dayLogStatus
    }

    static func notes(taskId: UUID, day: Date, logs: [TaskDayLog]) -> String {
        log(for: taskId, day: day, logs: logs)?.notes ?? ""
    }

    static func hasDayNote(taskId: UUID, day: Date, logs: [TaskDayLog]) -> Bool {
        log(for: taskId, day: day, logs: logs)?.hasDayNote == true
    }

    @discardableResult
    static func upsert(
        taskId: UUID,
        day: Date,
        status: DayLogStatus,
        at resolvedAt: Date = Date(),
        in context: ModelContext,
        source: String = "unknown"
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
        let statusName = status == .kept ? "kept" : "skipped"
        onAnalytics?(statusName, source, day.startOfLocalDay)
        return row
    }

    /// Saves the per-day note. Creates a note-only row when needed. Empty note + no mark deletes the row.
    @discardableResult
    static func setNotes(
        taskId: UUID,
        day: Date,
        notes: String,
        in context: ModelContext,
        source: String = "unknown"
    ) -> TaskDayLog? {
        let key = day.startOfLocalDay.localDayKey
        let now = Date()
        let clipped = String(notes.prefix(AppDefaults.notesMaxLength))
        let trimmedEmpty = clipped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if let existing = fetchLog(taskId: taskId, dayKey: key, in: context) {
            if trimmedEmpty, existing.dayLogStatus == nil {
                context.delete(existing)
                try? context.save()
                SyncRecorder.logDeleted(taskId: taskId, dayKey: key, at: now, in: context)
                refreshAfterChange(context: context)
                onAnalytics?("day_note_cleared", source, day.startOfLocalDay)
                return nil
            }
            existing.notes = clipped
            existing.updatedAt = now
            try? context.save()
            SyncRecorder.logChanged(taskId: taskId, dayKey: key, at: now, in: context)
            refreshAfterChange(context: context)
            onAnalytics?(trimmedEmpty ? "day_note_cleared" : "day_note_saved", source, day.startOfLocalDay)
            return existing
        }

        guard !trimmedEmpty else { return nil }
        let row = TaskDayLog(
            taskId: taskId,
            dayKey: key,
            status: nil,
            notes: clipped,
            resolvedAt: now,
            updatedAt: now
        )
        context.insert(row)
        try? context.save()
        SyncRecorder.logChanged(taskId: taskId, dayKey: key, at: now, in: context)
        refreshAfterChange(context: context)
        onAnalytics?("day_note_saved", source, day.startOfLocalDay)
        return row
    }

    static func markKept(
        taskId: UUID,
        day: Date,
        at date: Date = Date(),
        in context: ModelContext,
        source: String = "unknown"
    ) {
        upsert(taskId: taskId, day: day.startOfLocalDay, status: .kept, at: date, in: context, source: source)
    }

    static func markSkipped(
        taskId: UUID,
        day: Date,
        at date: Date = Date(),
        in context: ModelContext,
        source: String = "unknown"
    ) {
        upsert(taskId: taskId, day: day.startOfLocalDay, status: .skipped, at: date, in: context, source: source)
    }

    /// Clears kept/skipped only. Keeps a non-empty day note.
    static func clearLog(
        taskId: UUID,
        day: Date,
        in context: ModelContext,
        source: String = "unknown"
    ) {
        let key = day.startOfLocalDay.localDayKey
        guard let existing = fetchLog(taskId: taskId, dayKey: key, in: context) else { return }
        let now = Date()
        if existing.hasDayNote {
            existing.dayLogStatus = nil
            existing.updatedAt = now
            try? context.save()
            SyncRecorder.logChanged(taskId: taskId, dayKey: key, at: now, in: context)
            refreshAfterChange(context: context)
            onAnalytics?("cleared", source, day.startOfLocalDay)
        } else {
            context.delete(existing)
            try? context.save()
            SyncRecorder.logDeleted(taskId: taskId, dayKey: key, at: now, in: context)
            refreshAfterChange(context: context)
            onAnalytics?("cleared", source, day.startOfLocalDay)
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
