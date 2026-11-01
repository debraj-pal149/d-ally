import Foundation
import SwiftData

@Model
final class TaskDayLog {
    var id: UUID
    var taskId: UUID
    var dayKey: String
    /// `kept` / `skipped`, or empty when this row only holds a day note.
    var status: String
    var notes: String = ""
    var resolvedAt: Date
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        taskId: UUID,
        dayKey: String,
        status: DayLogStatus? = nil,
        notes: String = "",
        resolvedAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.dayKey = dayKey
        self.status = status?.rawValue ?? ""
        self.notes = notes
        self.resolvedAt = resolvedAt
        self.updatedAt = updatedAt ?? resolvedAt
    }

    var dayLogStatus: DayLogStatus? {
        get { DayLogStatus(rawValue: status) }
        set { status = newValue?.rawValue ?? "" }
    }

    var hasDayNote: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
