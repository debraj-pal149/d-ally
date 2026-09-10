import Foundation
import SwiftData

@Model
final class DailyTask {
    var id: UUID
    var name: String
    var notes: String
    var scheduleKind: String
    var hour: Int
    var minute: Int
    var windowEndHour: Int
    var windowEndMinute: Int
    var priority: String
    var colorHex: String
    var markPattern: String = MarkPattern.solid.rawValue
    var startDate: Date
    var endDate: Date?
    var isStopped: Bool
    var overdueReminderMode: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var notificationsEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        scheduleKind: ScheduleKind = .fixedTime,
        hour: Int = 9,
        minute: Int = 0,
        windowEndHour: Int = 0,
        windowEndMinute: Int = 0,
        priority: PriorityLevel = .normal,
        colorHex: String,
        markPattern: MarkPattern = .solid,
        startDate: Date = Date().startOfLocalDay,
        endDate: Date? = nil,
        isStopped: Bool = false,
        overdueReminderMode: OverdueReminderMode = .onceAfter10Minutes,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortOrder: Int = 0,
        notificationsEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.scheduleKind = scheduleKind.rawValue
        self.hour = hour
        self.minute = minute
        self.windowEndHour = windowEndHour
        self.windowEndMinute = windowEndMinute
        self.priority = priority.rawValue
        self.colorHex = colorHex
        self.markPattern = markPattern.rawValue
        self.startDate = startDate.startOfLocalDay
        self.endDate = endDate?.startOfLocalDay
        self.isStopped = isStopped
        self.overdueReminderMode = overdueReminderMode.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.notificationsEnabled = notificationsEnabled
    }

    var schedule: ScheduleKind {
        get { ScheduleKind(rawValue: scheduleKind) ?? .fixedTime }
        set { scheduleKind = newValue.rawValue }
    }

    var priorityLevel: PriorityLevel {
        get { PriorityLevel(rawValue: priority) ?? .normal }
        set { priority = newValue.rawValue }
    }

    var overdueMode: OverdueReminderMode {
        get { OverdueReminderMode(rawValue: overdueReminderMode) ?? .onceAfter10Minutes }
        set { overdueReminderMode = newValue.rawValue }
    }

    var markPatternKind: MarkPattern {
        get { MarkPattern(rawValue: markPattern) ?? .solid }
        set { markPattern = newValue.rawValue }
    }

    func nudgeDate(on day: Date) -> Date {
        Calendar.current.date(on: day, hour: hour, minute: minute)
    }

    func dueDate(on day: Date) -> Date {
        switch schedule {
        case .fixedTime:
            return nudgeDate(on: day)
        case .flexibleUntil:
            return Calendar.current.date(on: day, hour: windowEndHour, minute: windowEndMinute)
        }
    }

    func isActive(on day: Date) -> Bool {
        guard !isStopped else { return false }
        let dayStart = day.startOfLocalDay
        if dayStart < startDate.startOfLocalDay { return false }
        if let end = endDate, dayStart > end.startOfLocalDay { return false }
        return true
    }

    var displayTimeLabel: String {
        switch schedule {
        case .fixedTime:
            return TimeDisplay.clock(hour: hour, minute: minute)
        case .flexibleUntil:
            return "Before \(TimeDisplay.clock(hour: windowEndHour, minute: windowEndMinute))"
        }
    }

    var rowTimeLabel: String {
        switch schedule {
        case .fixedTime:
            return TimeDisplay.clock(hour: hour, minute: minute)
        case .flexibleUntil:
            return "by \(TimeDisplay.clock(hour: windowEndHour, minute: windowEndMinute))"
        }
    }

    static func flexibleWindowValid(nudgeHour: Int, nudgeMinute: Int, endHour: Int, endMinute: Int) -> Bool {
        (nudgeHour * 60 + nudgeMinute) <= (endHour * 60 + endMinute)
    }
}
