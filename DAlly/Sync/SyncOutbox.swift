import Foundation
import SwiftData

/// One pending change to send to the profile. Deleted entries double as tombstones
/// until the cloud copy carries `deletedAt`.
@Model
final class SyncOutbox {
    @Attribute(.unique) var key: String
    var kind: String
    var recordKey: String
    /// Named to stay clear of Core Data's own `isDeleted`, which swallows a field called `deleted`.
    var isTombstone: Bool
    var changedAt: Date

    init(key: String, kind: SyncRecordKind, recordKey: String, isTombstone: Bool, changedAt: Date) {
        self.key = key
        self.kind = kind.rawValue
        self.recordKey = recordKey
        self.isTombstone = isTombstone
        self.changedAt = changedAt
    }

    var recordKind: SyncRecordKind {
        SyncRecordKind(rawValue: kind) ?? .habit
    }
}

enum SyncRecordKind: String {
    case habit
    case log

    func key(for recordKey: String) -> String {
        "\(rawValue):\(recordKey)"
    }
}

enum SyncKeys {
    static func log(taskId: UUID, dayKey: String) -> String {
        "\(taskId.uuidString)_\(dayKey)"
    }

    static func splitLog(_ recordKey: String) -> (taskId: UUID, dayKey: String)? {
        guard let underscore = recordKey.lastIndex(of: "_") else { return nil }
        let idPart = String(recordKey[..<underscore])
        let dayPart = String(recordKey[recordKey.index(after: underscore)...])
        guard let id = UUID(uuidString: idPart), dayPart.count == 10 else { return nil }
        return (id, dayPart)
    }
}
