import Foundation

struct WeeklyReviewAnalysis: Equatable {
    struct Summary: Equatable {
        var kept: Int
        var skipped: Int
        var missed: Int
        var scheduled: Int

        var percentage: Int {
            guard scheduled > 0 else { return 0 }
            return Int((Double(kept) / Double(scheduled) * 100).rounded())
        }
    }

    struct Day: Identifiable, Equatable {
        var date: Date
        var kept: Int
        var scheduled: Int
        var id: String { date.localDayKey }
    }

    struct TaskRhythm: Identifiable, Equatable {
        var id: UUID
        var name: String
        var colorHex: String
        var kept: Int
        var scheduled: Int
        var previousPercentage: Int?

        var percentage: Int {
            guard scheduled > 0 else { return 0 }
            return Int((Double(kept) / Double(scheduled) * 100).rounded())
        }

        var comparisonText: String? {
            guard let previousPercentage else { return nil }
            let change = percentage - previousPercentage
            if change > 0 { return "+\(change)% from last week" }
            if change < 0 { return "\(abs(change))% below last week" }
            return "Same as last week"
        }
    }

    var weekStart: Date
    var weekEnd: Date
    var currentWeek: Summary
    var previousWeek: Summary?
    var monthToDate: Summary
    var days: [Day]
    var taskRhythms: [TaskRhythm]

    var weekComparisonText: String? {
        guard let previousWeek else { return nil }
        let change = currentWeek.percentage - previousWeek.percentage
        if change > 0 { return "Up \(change)% from last week" }
        if change < 0 { return "\(abs(change))% below last week" }
        return "Same as last week"
    }
}

enum WeeklyReviewAnalysisService {
    static func make(
        tasks: [DailyTask],
        logs: [TaskDayLog],
        now: Date = Date(),
        calendar suppliedCalendar: Calendar = .current
    ) -> WeeklyReviewAnalysis {
        var calendar = suppliedCalendar
        calendar.firstWeekday = 2 // The Sunday review closes a Monday–Sunday week.
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let previousEnd = calendar.date(byAdding: .day, value: -1, to: weekStart) ?? weekStart
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: today)
        ) ?? today

        let current = summary(
            tasks: tasks,
            logs: logs,
            from: weekStart,
            through: weekEnd,
            now: now,
            calendar: calendar
        )
        let previous = summary(
            tasks: tasks,
            logs: logs,
            from: previousStart,
            through: previousEnd,
            now: now,
            calendar: calendar
        )
        let month = summary(
            tasks: tasks,
            logs: logs,
            from: monthStart,
            through: today,
            now: now,
            calendar: calendar
        )

        let days = (0..<7).compactMap { offset -> WeeklyReviewAnalysis.Day? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let daySummary = summary(
                tasks: tasks,
                logs: logs,
                from: day,
                through: day,
                now: now,
                calendar: calendar
            )
            return WeeklyReviewAnalysis.Day(
                date: day,
                kept: daySummary.kept,
                scheduled: daySummary.scheduled
            )
        }

        let taskRhythms = tasks.filter(\.isLive).compactMap { task -> WeeklyReviewAnalysis.TaskRhythm? in
            let currentTask = summary(
                tasks: [task],
                logs: logs,
                from: weekStart,
                through: weekEnd,
                now: now,
                calendar: calendar
            )
            guard currentTask.scheduled > 0 else { return nil }
            let previousTask = summary(
                tasks: [task],
                logs: logs,
                from: previousStart,
                through: previousEnd,
                now: now,
                calendar: calendar
            )
            return WeeklyReviewAnalysis.TaskRhythm(
                id: task.id,
                name: task.name,
                colorHex: task.colorHex,
                kept: currentTask.kept,
                scheduled: currentTask.scheduled,
                previousPercentage: previousTask.scheduled > 0 ? previousTask.percentage : nil
            )
        }
        .sorted {
            if $0.percentage != $1.percentage { return $0.percentage > $1.percentage }
            if $0.kept != $1.kept { return $0.kept > $1.kept }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return WeeklyReviewAnalysis(
            weekStart: weekStart,
            weekEnd: weekEnd,
            currentWeek: current,
            previousWeek: previous.scheduled > 0 ? previous : nil,
            monthToDate: month,
            days: days,
            taskRhythms: taskRhythms
        )
    }

    private static func summary(
        tasks: [DailyTask],
        logs: [TaskDayLog],
        from start: Date,
        through end: Date,
        now: Date,
        calendar: Calendar
    ) -> WeeklyReviewAnalysis.Summary {
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay, startDay <= today else {
            return .init(kept: 0, skipped: 0, missed: 0, scheduled: 0)
        }

        var result = WeeklyReviewAnalysis.Summary(kept: 0, skipped: 0, missed: 0, scheduled: 0)
        var day = startDay
        while day <= min(endDay, today) {
            let isToday = calendar.isDate(day, inSameDayAs: today)
            for task in tasks where isEligible(task, on: day) {
                let status = DayLogService.status(taskId: task.id, day: day, logs: logs)
                // An open task today is not a miss. Past open tasks are.
                if isToday && status == nil { continue }
                result.scheduled += 1
                switch status {
                case .kept?: result.kept += 1
                case .skipped?: result.skipped += 1
                case nil: result.missed += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return result
    }

    private static func isEligible(_ task: DailyTask, on day: Date) -> Bool {
        task.isLive ? task.isScheduled(on: day) : task.belongsInEndedHistory(on: day)
    }
}
