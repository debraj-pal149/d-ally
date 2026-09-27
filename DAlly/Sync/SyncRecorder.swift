import Foundation
import SwiftData

/// Every local write goes through here so the profile learns about it.
/// The widget process records changes too; the app pushes them next time it runs.
enum SyncRecorder {
    /// Set by the app process to push right away. The widget leaves it nil.
    nonisolated(unsafe) static var onLocalChange: (() -> Void)?

    static func habitChanged(_ id: UUID, at changedAt: Date = Date(), in context: ModelContext) {
        upsert(kind: .habit, recordKey: id.uuidString, deleted: false, changedAt: changedAt, in: context)
    }

    static func habitDeleted(_ id: UUID, at changedAt: Date = Date(), in context: ModelContext) {
        upsert(kind: .habit, recordKey: id.uuidString, deleted: true, changedAt: changedAt, in: context)
    }

    static func logChanged(taskId: UUID, dayKey: String, at changedAt: Date = Date(), in context: ModelContext) {
        upsert(kind: .log, recordKey: SyncKeys.log(taskId: taskId, dayKey: dayKey), deleted: false, changedAt: changedAt, in: context)
    }

    static func logDeleted(taskId: UUID, dayKey: String, at changedAt: Date = Date(), in context: ModelContext) {
        upsert(kind: .log, recordKey: SyncKeys.log(taskId: taskId, dayKey: dayKey), deleted: true, changedAt: changedAt, in: context)
    }

    /// Queues everything on this phone. Used once when a profile first meets local data.
    static func enqueueAll(in context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<DailyTask>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<TaskDayLog>())) ?? []
        for task in tasks {
            upsert(kind: .habit, recordKey: task.id.uuidString, deleted: false, changedAt: task.updatedAt, in: context, notify: false)
        }
        for log in logs {
            upsert(
                kind: .log,
                recordKey: SyncKeys.log(taskId: log.taskId, dayKey: log.dayKey),
                deleted: false,
                changedAt: log.updatedAt,
                in: context,
                notify: false
            )
        }
        try? context.save()
    }

    static func pending(in context: ModelContext) -> [SyncOutbox] {
        (try? context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.changedAt)]))) ?? []
    }

    static func pendingChange(kind: SyncRecordKind, recordKey: String, in context: ModelContext) -> SyncOutbox? {
        let wanted = kind.key(for: recordKey)
        return pending(in: context).first { $0.key == wanted }
    }

    static func remove(_ entry: SyncOutbox, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    static func clear(in context: ModelContext) {
        for entry in pending(in: context) {
            context.delete(entry)
        }
        try? context.save()
    }

    private static func upsert(
        kind: SyncRecordKind,
        recordKey: String,
        deleted: Bool,
        changedAt: Date,
        in context: ModelContext,
        notify: Bool = true
    ) {
        if let existing = pendingChange(kind: kind, recordKey: recordKey, in: context) {
            existing.isTombstone = deleted
            existing.changedAt = max(existing.changedAt, changedAt)
        } else {
            context.insert(SyncOutbox(key: kind.key(for: recordKey), kind: kind, recordKey: recordKey, isTombstone: deleted, changedAt: changedAt))
        }
        if notify {
            try? context.save()
            onLocalChange?()
        }
    }
}
