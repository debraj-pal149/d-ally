import Foundation

struct WidgetHabit: Identifiable, Equatable {
    var id: UUID
    var name: String
    var timeLabel: String
    var colorHex: String
    var status: DayLogStatus?
}

struct TodaySnapshot: Equatable {
    var dayKey: String
    var habits: [WidgetHabit]
    var nextRefresh: Date
    var storeReady: Bool = true

    var openCount: Int { habits.filter { $0.status == nil }.count }
    var keptCount: Int { habits.filter { $0.status == .kept }.count }

    var headline: String {
        if !storeReady { return "Open d·ally" }
        if habits.isEmpty { return "Nothing today" }
        if openCount == 0 { return "All kept" }
        return openCount == 1 ? "1 open" : "\(openCount) open"
    }

    static let placeholder = TodaySnapshot(
        dayKey: Date().localDayKey,
        habits: [
            WidgetHabit(id: UUID(), name: "Take morning pill", timeLabel: "8:00 AM", colorHex: "#007AFF", status: .kept),
            WidgetHabit(id: UUID(), name: "Gym", timeLabel: "by 9:00 PM", colorHex: "#34C759", status: nil),
        ],
        nextRefresh: Date().addingTimeInterval(3600)
    )
}

enum TodaySnapshotBuilder {
    static func make(tasks: [DailyTask], logs: [TaskDayLog], now: Date = Date()) -> TodaySnapshot {
        let today = now.startOfLocalDay
        let active = TaskOccurrenceService.tasks(for: today, allTasks: tasks)
        let habits = active.map { task in
            WidgetHabit(
                id: task.id,
                name: task.name,
                timeLabel: task.rowTimeLabel,
                colorHex: task.colorHex,
                status: DayLogService.status(taskId: task.id, day: today, logs: logs)
            )
        }
        return TodaySnapshot(
            dayKey: today.localDayKey,
            habits: habits,
            nextRefresh: nextRefresh(tasks: active, now: now)
        )
    }

    static func nextRefresh(tasks: [DailyTask], now: Date) -> Date {
        let today = now.startOfLocalDay
        var candidates = [today.addingLocalDays(1), now.addingTimeInterval(30 * 60)]
        for task in tasks {
            let due = task.dueDate(on: today)
            if due > now { candidates.append(due) }
        }
        return candidates.min() ?? now.addingTimeInterval(30 * 60)
    }
}
