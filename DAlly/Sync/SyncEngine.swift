import FirebaseFirestore
import Foundation
import Observation
import SwiftData
import WidgetKit

struct MergeSummary: Equatable {
    var habits: Int
    var days: Int
}

/// Keeps the phone's store and the signed-in profile in step.
/// Local writes queue in `SyncOutbox`; the profile streams back through listeners.
@MainActor
@Observable
final class SyncEngine {
    static let shared = SyncEngine()

    enum State: Equatable {
        case off
        case syncing
        case synced(Date)
        case offline
        case error(String)
    }

    private(set) var state: State = .off
    private(set) var mergeInProgress = false
    var mergeSummary: MergeSummary?

    private var uid: String?
    private var habitListener: ListenerRegistration?
    private var logListener: ListenerRegistration?
    private var bookmarkListener: ListenerRegistration?
    private var isPushing = false
    private var pushRequested = false
    private var habitsFromServer = false
    private var logsFromServer = false
    private var bookmarksFromServer = false

    private var context: ModelContext { Persistence.shared.mainContext }
    private var db: Firestore { Firestore.firestore() }

    private init() {}

    // MARK: Lifecycle

    func start(uid: String) {
        stopListeners()
        self.uid = uid
        habitsFromServer = false
        logsFromServer = false
        bookmarksFromServer = false

        if !Self.mergeDone(uid: uid) {
            let hasLocal = localHabitCount() > 0 || localLogCount() > 0 || localBookmarkCount() > 0
            mergeInProgress = hasLocal
            if hasLocal {
                Persistence.backupStore(label: "before-signin")
            }
            SyncRecorder.enqueueAll(in: context)
        }

        SyncRecorder.onLocalChange = { [weak self] in
            Task { @MainActor in self?.pushNow() }
        }
        state = .syncing
        attachListeners(uid: uid)
        pushNow()
    }

    func stop() {
        stopListeners()
        SyncRecorder.onLocalChange = nil
        uid = nil
        state = .off
        mergeInProgress = false
    }

    private func stopListeners() {
        habitListener?.remove()
        logListener?.remove()
        bookmarkListener?.remove()
        habitListener = nil
        logListener = nil
        bookmarkListener = nil
    }

    // MARK: Merge bookkeeping

    static func mergeDone(uid: String) -> Bool {
        UserDefaults.standard.bool(forKey: "syncMergeDone.\(uid)")
    }

    static func clearMergeMarker(uid: String) {
        UserDefaults.standard.removeObject(forKey: "syncMergeDone.\(uid)")
    }

    private func finishMergeIfReady() {
        guard let uid, !Self.mergeDone(uid: uid) else { return }
        guard habitsFromServer, logsFromServer, bookmarksFromServer else { return }
        guard SyncRecorder.pending(in: context).isEmpty else { return }
        UserDefaults.standard.set(true, forKey: "syncMergeDone.\(uid)")
        UserDefaults.standard.set(uid, forKey: AppStorageKey.localDataOwnerUID)
        if mergeInProgress {
            mergeSummary = MergeSummary(habits: localHabitCount(), days: localLogCount())
        }
        mergeInProgress = false
    }

    // MARK: Local counts

    func localHabitCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<DailyTask>())) ?? 0
    }

    func localLogCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<TaskDayLog>())) ?? 0
    }

    func localBookmarkCount() -> Int {
        (try? context.fetchCount(FetchDescriptor<DayBookmark>())) ?? 0
    }

    /// Removes every habit and day on this phone. Used only after the person chose it.
    func wipeLocalData() {
        let tasks = (try? context.fetch(FetchDescriptor<DailyTask>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<TaskDayLog>())) ?? []
        let bookmarks = (try? context.fetch(FetchDescriptor<DayBookmark>())) ?? []
        tasks.forEach(context.delete)
        logs.forEach(context.delete)
        bookmarks.forEach(context.delete)
        try? context.save()
        SyncRecorder.clear(in: context)
        afterInbound()
    }

    // MARK: Push

    func pushNow() {
        guard uid != nil else { return }
        if isPushing {
            pushRequested = true
            return
        }
        isPushing = true
        Task {
            await drain()
            isPushing = false
            if pushRequested {
                pushRequested = false
                pushNow()
            } else {
                finishMergeIfReady()
            }
        }
    }

    private func drain() async {
        guard let uid else { return }
        let entries = SyncRecorder.pending(in: context)
        guard !entries.isEmpty else {
            if case .syncing = state { state = .synced(Date()) }
            return
        }
        state = .syncing
        for entry in entries {
            do {
                try await push(entry, uid: uid)
                SyncRecorder.remove(entry, in: context)
            } catch {
                state = Self.isOffline(error) ? .offline : .error(error.localizedDescription)
                return
            }
        }
        state = .synced(Date())
    }

    private func push(_ entry: SyncOutbox, uid: String) async throws {
        let base = db.collection("users").document(uid)
        let ref: DocumentReference
        let data: [String: Any]

        switch entry.recordKind {
        case .habit:
            guard let id = UUID(uuidString: entry.recordKey) else { return }
            ref = base.collection("habits").document(entry.recordKey)
            if !entry.isTombstone, let task = fetchTask(id) {
                data = CloudCodec.habit(from: task)
            } else {
                data = CloudCodec.habitTombstone(id: id, deletedAt: entry.changedAt)
            }
        case .log:
            guard let parts = SyncKeys.splitLog(entry.recordKey) else { return }
            ref = base.collection("logs").document(entry.recordKey)
            if !entry.isTombstone, let log = DayLogService.fetchLog(taskId: parts.taskId, dayKey: parts.dayKey, in: context) {
                data = CloudCodec.log(from: log)
            } else {
                data = CloudCodec.logTombstone(taskId: parts.taskId, dayKey: parts.dayKey, deletedAt: entry.changedAt)
            }
        case .bookmark:
            guard let id = UUID(uuidString: entry.recordKey) else { return }
            ref = base.collection("bookmarks").document(entry.recordKey)
            if !entry.isTombstone, let bookmark = fetchBookmark(id) {
                data = CloudCodec.bookmark(from: bookmark)
            } else {
                data = CloudCodec.bookmarkTombstone(id: id, deletedAt: entry.changedAt)
            }
        }

        let localChangedAt = (data["updatedAt"] as? Date) ?? entry.changedAt
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            let remoteUpdated = (snapshot.data()?["updatedAt"] as? Timestamp)?.dateValue()
            if SyncMerge.shouldPush(localChangedAt: localChangedAt, remoteUpdatedAt: remoteUpdated) {
                transaction.setData(data, forDocument: ref)
            }
            return nil
        }
    }

    // MARK: Listen

    private func attachListeners(uid: String) {
        let base = db.collection("users").document(uid)
        habitListener = base.collection("habits").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                self?.handleHabits(snapshot, error: error)
            }
        }
        logListener = base.collection("logs").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                self?.handleLogs(snapshot, error: error)
            }
        }
        bookmarkListener = base.collection("bookmarks").addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
            Task { @MainActor in
                self?.handleBookmarks(snapshot, error: error)
            }
        }
    }

    private func handleHabits(_ snapshot: QuerySnapshot?, error: Error?) {
        guard let snapshot else {
            if let error { state = Self.isOffline(error) ? .offline : .error(error.localizedDescription) }
            return
        }
        var changed = false
        for change in snapshot.documentChanges where change.type != .removed {
            guard let cloud = CloudCodec.decodeHabit(Self.normalize(change.document.data())) else { continue }
            let pending = SyncRecorder.pendingChange(kind: .habit, recordKey: cloud.id.uuidString, in: context)
            let local = fetchTask(cloud.id)
            let decision = SyncMerge.decide(
                localUpdatedAt: local?.updatedAt,
                localPendingAt: pending?.changedAt,
                remoteUpdatedAt: cloud.updatedAt
            )
            guard decision == .applyRemote else { continue }
            if cloud.deletedAt != nil, cloud.name.isEmpty {
                // Legacy hard tombstone: soft-delete locally and keep name/color when we have them.
                if let local {
                    local.deletedAt = cloud.deletedAt
                    local.isStopped = true
                    local.notificationsEnabled = false
                    local.updatedAt = cloud.updatedAt
                    changed = true
                }
            } else if let local {
                CloudCodec.apply(cloud, to: local)
                changed = true
            } else if !cloud.name.isEmpty {
                context.insert(CloudCodec.makeTask(from: cloud))
                changed = true
            }
            if let pending { context.delete(pending) }
        }
        if changed {
            try? context.save()
            afterInbound()
        }
        noteSnapshot(fromCache: snapshot.metadata.isFromCache, kind: .habits)
    }

    private func handleLogs(_ snapshot: QuerySnapshot?, error: Error?) {
        guard let snapshot else {
            if let error { state = Self.isOffline(error) ? .offline : .error(error.localizedDescription) }
            return
        }
        var changed = false
        for change in snapshot.documentChanges where change.type != .removed {
            guard let cloud = CloudCodec.decodeLog(Self.normalize(change.document.data())) else { continue }
            let recordKey = SyncKeys.log(taskId: cloud.taskId, dayKey: cloud.dayKey)
            let pending = SyncRecorder.pendingChange(kind: .log, recordKey: recordKey, in: context)
            let local = DayLogService.fetchLog(taskId: cloud.taskId, dayKey: cloud.dayKey, in: context)
            let decision = SyncMerge.decide(
                localUpdatedAt: local?.updatedAt,
                localPendingAt: pending?.changedAt,
                remoteUpdatedAt: cloud.updatedAt
            )
            guard decision == .applyRemote else { continue }
            if cloud.deletedAt != nil {
                if let local {
                    context.delete(local)
                    changed = true
                }
            } else if let local {
                local.status = cloud.status
                local.resolvedAt = cloud.resolvedAt
                local.updatedAt = cloud.updatedAt
                changed = true
            } else {
                let status = DayLogStatus(rawValue: cloud.status) ?? .kept
                context.insert(TaskDayLog(
                    taskId: cloud.taskId,
                    dayKey: cloud.dayKey,
                    status: status,
                    resolvedAt: cloud.resolvedAt,
                    updatedAt: cloud.updatedAt
                ))
                changed = true
            }
            if let pending { context.delete(pending) }
        }
        if changed {
            try? context.save()
            afterInbound()
        }
        noteSnapshot(fromCache: snapshot.metadata.isFromCache, kind: .logs)
    }

    private func handleBookmarks(_ snapshot: QuerySnapshot?, error: Error?) {
        guard let snapshot else {
            if let error { state = Self.isOffline(error) ? .offline : .error(error.localizedDescription) }
            return
        }
        var changed = false
        for change in snapshot.documentChanges where change.type != .removed {
            guard let cloud = CloudCodec.decodeBookmark(Self.normalize(change.document.data())) else { continue }
            let pending = SyncRecorder.pendingChange(kind: .bookmark, recordKey: cloud.id.uuidString, in: context)
            let local = fetchBookmark(cloud.id)
            let decision = SyncMerge.decide(
                localUpdatedAt: local?.updatedAt,
                localPendingAt: pending?.changedAt,
                remoteUpdatedAt: cloud.updatedAt
            )
            guard decision == .applyRemote else { continue }
            if cloud.deletedAt != nil, cloud.title.isEmpty {
                if let local {
                    local.deletedAt = cloud.deletedAt
                    local.updatedAt = cloud.updatedAt
                    changed = true
                }
            } else if let local {
                CloudCodec.apply(cloud, to: local)
                changed = true
            } else if !cloud.title.isEmpty {
                context.insert(CloudCodec.makeBookmark(from: cloud))
                changed = true
            }
            if let pending { context.delete(pending) }
        }
        if changed {
            try? context.save()
            afterInbound()
        }
        noteSnapshot(fromCache: snapshot.metadata.isFromCache, kind: .bookmarks)
    }

    private enum SnapshotKind { case habits, logs, bookmarks }

    private func noteSnapshot(fromCache: Bool, kind: SnapshotKind) {
        if fromCache {
            if habitsFromServer && logsFromServer && bookmarksFromServer, case .synced = state {
                state = .offline
            }
            return
        }
        switch kind {
        case .habits: habitsFromServer = true
        case .logs: logsFromServer = true
        case .bookmarks: bookmarksFromServer = true
        }
        if habitsFromServer && logsFromServer && bookmarksFromServer {
            if SyncRecorder.pending(in: context).isEmpty {
                if case .error = state {} else { state = .synced(Date()) }
                finishMergeIfReady()
            } else {
                pushNow()
            }
        }
    }

    private func afterInbound() {
        NotificationSchedulingService.shared.rescheduleFromStore(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: Cloud removal

    func deleteCloudData(uid: String) async throws {
        let base = db.collection("users").document(uid)
        for name in ["habits", "logs", "bookmarks"] {
            var last: DocumentSnapshot?
            while true {
                var query = base.collection(name).order(by: FieldPath.documentID()).limit(to: 300)
                if let last { query = query.start(afterDocument: last) }
                let page = try await query.getDocuments()
                if page.documents.isEmpty { break }
                let batch = db.batch()
                page.documents.forEach { batch.deleteDocument($0.reference) }
                try await batch.commit()
                last = page.documents.last
                if page.documents.count < 300 { break }
            }
        }
        try await base.delete()
    }

    // MARK: Helpers

    private func fetchTask(_ id: UUID) -> DailyTask? {
        let descriptor = FetchDescriptor<DailyTask>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    private func fetchBookmark(_ id: UUID) -> DayBookmark? {
        let descriptor = FetchDescriptor<DayBookmark>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    private static func normalize(_ data: [String: Any]) -> [String: Any] {
        var out = data
        for (key, value) in data {
            if let stamp = value as? Timestamp {
                out[key] = stamp.dateValue()
            }
        }
        return out
    }

    private static func isOffline(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == FirestoreErrorDomain && nsError.code == FirestoreErrorCode.unavailable.rawValue
    }
}
