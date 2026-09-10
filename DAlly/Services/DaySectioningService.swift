import Foundation

enum DaySectionID: String, Identifiable, Hashable {
    case kept
    case skipped
    case pastDue
    case nextHour
    case later
    case missed
    case scheduled

    var id: String { rawValue }

    func title(isToday: Bool) -> String {
        switch self {
        case .kept: isToday ? "Kept today" : "Kept"
        case .skipped: "Skipped"
        case .pastDue: "Past due"
        case .nextHour: "Next hour"
        case .later: "Later today"
        case .missed: "Missed"
        case .scheduled: "Scheduled"
        }
    }

    var opacity: Double {
        switch self {
        case .kept: 1.0
        case .skipped: 0.88
        case .pastDue: 1.0
        case .nextHour: 0.92
        case .later: 0.58
        case .missed: 0.62
        case .scheduled: 0.62
        }
    }
}

struct DaySection: Identifiable {
    let id: DaySectionID
    let tasks: [DailyTask]
}

enum DayKind {
    case past, today, future
}

enum DaySectioningService {
    static func kind(of day: Date, now: Date = Date()) -> DayKind {
        let cal = Calendar.current
        if cal.isDate(day, inSameDayAs: now) { return .today }
        if day.startOfLocalDay < now.startOfLocalDay { return .past }
        return .future
    }

    static func sections(
        day: Date,
        tasks: [DailyTask],
        logs: [TaskDayLog],
        now: Date = Date()
    ) -> [DaySection] {
        let active = TaskOccurrenceService.tasks(for: day, allTasks: tasks)
        switch kind(of: day, now: now) {
        case .today:
            return todaySections(day: day, tasks: active, logs: logs, now: now)
        case .past:
            return pastSections(day: day, tasks: active, logs: logs)
        case .future:
            return futureSections(tasks: active)
        }
    }

    private static func todaySections(day: Date, tasks: [DailyTask], logs: [TaskDayLog], now: Date) -> [DaySection] {
        var kept: [DailyTask] = []
        var skipped: [DailyTask] = []
        var pastDue: [DailyTask] = []
        var nextHour: [DailyTask] = []
        var later: [DailyTask] = []

        for task in tasks {
            let status = DayLogService.status(taskId: task.id, day: day, logs: logs)
            if status == .kept {
                kept.append(task)
                continue
            }
            if status == .skipped {
                skipped.append(task)
                continue
            }
            let due = task.dueDate(on: day)
            let nudge = task.nudgeDate(on: day)
            if due < now {
                pastDue.append(task)
            } else if isNextHour(due: due, nudge: nudge, now: now) {
                nextHour.append(task)
            } else {
                later.append(task)
            }
        }

        func byDue(_ a: DailyTask, _ b: DailyTask) -> Bool {
            let da = a.dueDate(on: day)
            let db = b.dueDate(on: day)
            if da != db { return da < db }
            let na = a.nudgeDate(on: day)
            let nb = b.nudgeDate(on: day)
            if na != nb { return na < nb }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }

        kept.sort(by: byDue)
        skipped.sort(by: byDue)
        pastDue.sort(by: byDue)
        nextHour.sort(by: byDue)
        later.sort(by: byDue)

        return pack([
            (.kept, kept),
            (.skipped, skipped),
            (.pastDue, pastDue),
            (.nextHour, nextHour),
            (.later, later)
        ])
    }

    static func isNextHour(due: Date, nudge: Date, now: Date) -> Bool {
        let window = now.addingTimeInterval(3600)
        if due > now && due <= window { return true }
        if due >= now && nudge > now && nudge <= window { return true }
        return false
    }

    private static func pastSections(day: Date, tasks: [DailyTask], logs: [TaskDayLog]) -> [DaySection] {
        var kept: [DailyTask] = []
        var skipped: [DailyTask] = []
        var missed: [DailyTask] = []
        for task in tasks {
            switch DayLogService.status(taskId: task.id, day: day, logs: logs) {
            case .kept: kept.append(task)
            case .skipped: skipped.append(task)
            case nil: missed.append(task)
            }
        }
        return pack([(.kept, kept), (.skipped, skipped), (.missed, missed)])
    }

    private static func futureSections(tasks: [DailyTask]) -> [DaySection] {
        pack([(.scheduled, tasks)])
    }

    private static func pack(_ items: [(DaySectionID, [DailyTask])]) -> [DaySection] {
        items.compactMap { id, tasks in
            tasks.isEmpty ? nil : DaySection(id: id, tasks: tasks)
        }
    }
}
