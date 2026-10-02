import Foundation

/// Plain JSON of every habit, marked day, and day bookmark. A backup that needs no account.
enum HistoryExport {
    static func makeFile(tasks: [DailyTask], logs: [TaskDayLog], bookmarks: [DayBookmark] = []) throws -> URL {
        let iso = ISO8601DateFormatter()
        let habits: [[String: Any]] = tasks.map { task in
            var item = CloudCodec.habit(from: task)
            item["createdAt"] = iso.string(from: task.createdAt)
            item["updatedAt"] = iso.string(from: task.updatedAt)
            if let deletedAt = task.deletedAt {
                item["deletedAt"] = iso.string(from: deletedAt)
            } else {
                item.removeValue(forKey: "deletedAt")
            }
            item["repeat"] = task.repeatSummary
            item["time"] = task.displayTimeLabel
            return item
        }
        let days: [[String: Any]] = logs
            .sorted { $0.dayKey < $1.dayKey }
            .map { log in
                [
                    "taskId": log.taskId.uuidString,
                    "day": log.dayKey,
                    "status": log.status,
                    "resolvedAt": iso.string(from: log.resolvedAt),
                ]
            }
        let bookmarkRows: [[String: Any]] = bookmarks
            .sorted { $0.dayKey < $1.dayKey }
            .map { bookmark in
                var item: [String: Any] = [
                    "id": bookmark.id.uuidString,
                    "title": bookmark.title,
                    "notes": bookmark.notes,
                    "day": bookmark.dayKey,
                    "createdAt": iso.string(from: bookmark.createdAt),
                    "updatedAt": iso.string(from: bookmark.updatedAt),
                ]
                if let deletedAt = bookmark.deletedAt {
                    item["deletedAt"] = iso.string(from: deletedAt)
                }
                return item
            }
        let payload: [String: Any] = [
            "app": AppCopy.brand,
            "exportedAt": iso.string(from: Date()),
            "habits": habits,
            "days": days,
            "bookmarks": bookmarkRows,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        let name = "dally-history-\(Date().localDayKey).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
