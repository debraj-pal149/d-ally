import Foundation
import SwiftData

/// A one-day note. Not a reminder: no time, no repeat, no alert.
@Model
final class DayBookmark {
    var id: UUID
    var title: String
    var notes: String
    /// Local calendar day as `yyyy-MM-dd`.
    var dayKey: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dayKey: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dayKey = dayKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var isLive: Bool { deletedAt == nil }

    static func live(on day: Date, in bookmarks: [DayBookmark]) -> [DayBookmark] {
        let key = day.localDayKey
        return bookmarks
            .filter { $0.isLive && $0.dayKey == key }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }
}
