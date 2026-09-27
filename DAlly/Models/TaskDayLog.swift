import Foundation
import SwiftData

@Model
final class TaskDayLog {
    var id: UUID
    var taskId: UUID
    var dayKey: String
    var status: String
    var resolvedAt: Date
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        taskId: UUID,
        dayKey: String,
        status: DayLogStatus,
        resolvedAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.dayKey = dayKey
        self.status = status.rawValue
        self.resolvedAt = resolvedAt
        self.updatedAt = updatedAt ?? resolvedAt
    }

    var dayLogStatus: DayLogStatus {
        get { DayLogStatus(rawValue: status) ?? .kept }
        set { status = newValue.rawValue }
    }
}
