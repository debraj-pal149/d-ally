import Foundation
import SQLite3
import SwiftData

enum Persistence {
    static let modelTypes: [any PersistentModel.Type] = [DailyTask.self, TaskDayLog.self, SyncOutbox.self]

    /// A new Schema each time; SwiftData binds a Schema to the first container that uses it.
    static var schema: Schema { Schema(modelTypes) }

    static let shared: ModelContainer = {
        let schema = Self.schema
        let config = configuration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    static var storeURL: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedSettings.appGroupID) else { return nil }
        let dir = container.appendingPathComponent("Library/Application Support", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("DAlly.store")
    }

    /// The app's private store. Installs before the shared group kept habits here.
    static var legacyStoreURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DAlly.store")
    }

    /// Folder of store snapshots taken before a merge. Never auto-deleted.
    static var backupsDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func configuration(schema: Schema) -> ModelConfiguration {
        if SharedSettings.isExtension {
            if let url = storeURL, FileManager.default.fileExists(atPath: url.path) {
                return ModelConfiguration(schema: schema, url: url)
            }
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }

        migrateStoreIfNeeded()
        if let url = storeURL {
            return ModelConfiguration(schema: schema, url: url)
        }
        return ModelConfiguration("DAlly", schema: schema)
    }

    /// Copies the private store into the app group once, so existing habits survive.
    /// The widget does not create the shared file; an empty file would hide the real habits.
    static func migrateStoreIfNeeded() {
        let fm = FileManager.default
        guard let destination = storeURL, let source = legacyStoreURL else { return }
        guard fm.fileExists(atPath: source.path) else { return }

        let destinationMissing = !fm.fileExists(atPath: destination.path)
        let destinationEmpty = !destinationMissing && habitCount(at: destination) == 0 && habitCount(at: source) > 0
        guard destinationMissing || destinationEmpty else { return }

        if destinationEmpty {
            for suffix in ["", "-wal", "-shm"] {
                try? fm.removeItem(at: URL(fileURLWithPath: destination.path + suffix))
            }
        }
        copyStore(from: source, to: destination)
    }

    /// Snapshot of the live store, taken before any merge touches it.
    @discardableResult
    static func backupStore(label: String) -> URL? {
        guard let source = storeURL, let dir = backupsDirectory else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let destination = dir.appendingPathComponent("\(label)-\(stamp).store")
        checkpoint(at: source)
        copyStore(from: source, to: destination)
        return FileManager.default.fileExists(atPath: destination.path) ? destination : nil
    }

    private static func copyStore(from source: URL, to destination: URL) {
        let fm = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let from = URL(fileURLWithPath: source.path + suffix)
            let to = URL(fileURLWithPath: destination.path + suffix)
            guard fm.fileExists(atPath: from.path) else { continue }
            try? fm.copyItem(at: from, to: to)
        }
    }

    private static func checkpoint(at url: URL) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }
        sqlite3_wal_checkpoint_v2(db, nil, SQLITE_CHECKPOINT_PASSIVE, nil, nil)
    }

    static func habitCount(at url: URL) -> Int {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM ZDAILYTASK", -1, &statement, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(statement, 0))
    }
}
