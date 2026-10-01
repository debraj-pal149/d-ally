import Foundation

enum TaskOccurrenceService {
    static func tasks(for day: Date, allTasks: [DailyTask]) -> [DailyTask] {
        allTasks
            .filter { $0.isActive(on: day) }
            .sorted(by: sortByTime(on: day))
    }

    /// Stopped or soft-deleted habits that actually ran on this day.
    /// Strict: start…historyEnd only. No log-only fallback (that pulled old habits onto today).
    static func endedHistory(for day: Date, allTasks: [DailyTask], logs: [TaskDayLog] = []) -> [DailyTask] {
        _ = logs
        return allTasks
            .filter { $0.belongsInEndedHistory(on: day) }
            .sorted(by: sortByTime(on: day))
    }

    private static func sortByTime(on day: Date) -> (DailyTask, DailyTask) -> Bool {
        { a, b in
            if a.hour != b.hour { return a.hour < b.hour }
            if a.minute != b.minute { return a.minute < b.minute }
            if a.priorityLevel.sortRank != b.priorityLevel.sortRank {
                return a.priorityLevel.sortRank < b.priorityLevel.sortRank
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
