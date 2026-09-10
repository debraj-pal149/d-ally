import Foundation

enum TaskOccurrenceService {
    static func tasks(for day: Date, allTasks: [DailyTask]) -> [DailyTask] {
        allTasks
            .filter { $0.isActive(on: day) }
            .sorted { a, b in
                if a.hour != b.hour { return a.hour < b.hour }
                if a.minute != b.minute { return a.minute < b.minute }
                if a.priorityLevel.sortRank != b.priorityLevel.sortRank {
                    return a.priorityLevel.sortRank < b.priorityLevel.sortRank
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
    }
}
