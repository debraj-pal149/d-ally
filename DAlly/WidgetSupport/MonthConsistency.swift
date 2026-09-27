import Foundation

enum MonthConsistency {
    struct Count: Equatable {
        var kept: Int
        var scheduled: Int

        var line: String? {
            guard scheduled > 0 else { return nil }
            return "Kept \(kept) of \(scheduled) this month"
        }
    }

    /// Scheduled days in the viewed month through yesterday.
    /// Today counts only after it is kept or skipped, so an open morning is not a miss.
    static func count(task: DailyTask, logs: [TaskDayLog], viewing day: Date, now: Date = Date()) -> Count {
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: day))?.startOfLocalDay ?? day.startOfLocalDay
        let today = now.startOfLocalDay
        guard monthStart <= today else { return Count(kept: 0, scheduled: 0) }

        let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)?.startOfLocalDay ?? monthStart
        let yesterday = today.addingLocalDays(-1)
        let end = min(monthEnd, yesterday)

        var kept = 0
        var scheduled = 0
        if end >= monthStart {
            var cursor = monthStart
            while cursor <= end {
                if task.isActive(on: cursor) {
                    scheduled += 1
                    if DayLogService.status(taskId: task.id, day: cursor, logs: logs) == .kept {
                        kept += 1
                    }
                }
                let next = cursor.addingLocalDays(1)
                if next <= cursor { break }
                cursor = next
            }
        }

        if today >= monthStart && today <= monthEnd && task.isActive(on: today) {
            if let status = DayLogService.status(taskId: task.id, day: today, logs: logs) {
                scheduled += 1
                if status == .kept { kept += 1 }
            }
        }

        return Count(kept: kept, scheduled: scheduled)
    }
}
