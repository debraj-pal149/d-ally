import SwiftUI

enum CalendarMarksMode: String, CaseIterable, Identifiable {
    case kept
    case missed
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kept: AppCopy.calendarModeKept
        case .missed: AppCopy.calendarModeMissed
        case .deleted: AppCopy.calendarModeDeleted
        }
    }
}

struct MonthGridView: View {
    var month: Date
    var selectedDay: Date?
    var tasks: [DailyTask]
    var logs: [TaskDayLog]
    var bookmarks: [DayBookmark] = []
    var marksMode: CalendarMarksMode = .kept
    /// Empty means every habit. Non-empty limits kept, skipped, and missed marks to these tasks.
    var focusedTaskIds: Set<UUID> = []
    var focusBookmarks: Bool = false
    var onSelect: (Date) -> Void

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        let days = daysInMonth()
        let rowCount = max(days.count / 7, 1)
        let weekdaySymbols = calendar.veryShortWeekdaySymbols
        let orderedSymbols = Array(
            weekdaySymbols[calendar.firstWeekday - 1..<weekdaySymbols.count]
                + weekdaySymbols[0..<calendar.firstWeekday - 1]
        )

        GeometryReader { geo in
            let weekdayH: CGFloat = 22
            let vSpacing: CGFloat = 4
            let usable = max(geo.size.height - weekdayH - vSpacing * CGFloat(rowCount), 1)
            let cellHeight = max(usable / CGFloat(rowCount), 56)

            VStack(spacing: vSpacing) {
                HStack(spacing: 0) {
                    ForEach(orderedSymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(AppTypography.captionSemibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: weekdayH)
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                    spacing: vSpacing
                ) {
                    ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                        if let day {
                            DayCellView(
                                day: day,
                                isSelected: selectedDay.map { Date.isSameLocalDay($0, day) } ?? false,
                                marks: marks(for: day),
                                cellHeight: cellHeight,
                                marksStyle: marksMode == .missed ? .missed : .kept
                            )
                            .onTapGesture { onSelect(day) }
                        } else {
                            Color.clear.frame(height: cellHeight)
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .padding(.horizontal, 10)
    }

    private func daysInMonth() -> [Date?] {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
        let range = calendar.range(of: .day, in: .month, for: start) ?? 1..<31
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            cells.append(calendar.date(byAdding: .day, value: day - 1, to: start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func marks(for day: Date) -> DayMarks {
        let today = Date().startOfLocalDay
        let dayStart = day.startOfLocalDay

        let byId = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        func included(_ task: DailyTask) -> Bool {
            focusedTaskIds.isEmpty || focusedTaskIds.contains(task.id)
        }

        let showHabits = !focusBookmarks
        let showBookmark = focusBookmarks || focusedTaskIds.isEmpty
        let bookmarkDot: [MarkDot] = {
            guard showBookmark,
                  bookmarks.contains(where: { $0.isLive && $0.dayKey == day.localDayKey })
            else { return [] }
            return [.bookmark]
        }()

        // Future days: habit marks stay empty; bookmarks still show.
        if dayStart > today {
            return DayMarks(dots: bookmarkDot, skipOnly: false)
        }

        switch marksMode {
        case .kept:
            guard showHabits else {
                return DayMarks(dots: bookmarkDot, skipOnly: false)
            }
            let key = day.localDayKey
            let dayLogs = logs.filter { $0.dayKey == key }
            let kept = dayLogs.filter { $0.dayLogStatus == .kept }
            let skipped = dayLogs.filter { $0.dayLogStatus == .skipped }
            let keptTasks = kept.compactMap { byId[$0.taskId] }
                .filter { $0.isLive && included($0) }
                .sorted { a, b in
                    let da = a.dueDate(on: day)
                    let db = b.dueDate(on: day)
                    if da != db { return da < db }
                    return a.name < b.name
                }
            let skippedFocused = skipped.compactMap { byId[$0.taskId] }
                .filter { $0.isLive && included($0) }
            let habitDots = keptTasks.map { MarkDot(hex: $0.colorHex, pattern: $0.markPatternKind) }
            return DayMarks(
                dots: bookmarkDot + habitDots,
                skipOnly: habitDots.isEmpty && bookmarkDot.isEmpty && !skippedFocused.isEmpty
            )

        case .missed:
            // Missed only applies to past days (open logs after the day ended).
            guard dayStart < today else {
                return DayMarks(dots: bookmarkDot, skipOnly: false)
            }
            guard showHabits else {
                return DayMarks(dots: bookmarkDot, skipOnly: false)
            }
            let active = TaskOccurrenceService.tasks(for: day, allTasks: tasks)
            let missed = active.filter {
                included($0) && DayLogService.status(taskId: $0.id, day: day, logs: logs) == nil
            }
                .sorted { a, b in
                    let da = a.dueDate(on: day)
                    let db = b.dueDate(on: day)
                    if da != db { return da < db }
                    return a.name < b.name
                }
            let habitDots = missed.map { MarkDot(hex: $0.colorHex, pattern: $0.markPatternKind) }
            return DayMarks(dots: bookmarkDot + habitDots, skipOnly: false)

        case .deleted:
            guard showHabits else {
                return DayMarks(dots: bookmarkDot, skipOnly: false)
            }
            let key = day.localDayKey
            let dayLogs = logs.filter { $0.dayKey == key }
            let deletedTasks: (TaskDayLog) -> DailyTask? = { log in
                guard let task = byId[log.taskId], task.deletedAt != nil else { return nil }
                guard dayStart <= task.deletedAt!.startOfLocalDay else { return nil }
                guard included(task) else { return nil }
                return task
            }
            let keptTasks = dayLogs.filter { $0.dayLogStatus == .kept }
                .compactMap(deletedTasks)
                .sorted { a, b in
                    let da = a.dueDate(on: day)
                    let db = b.dueDate(on: day)
                    if da != db { return da < db }
                    return a.name < b.name
                }
            let skippedFocused = dayLogs.filter { $0.dayLogStatus == .skipped }
                .compactMap(deletedTasks)
            let habitDots = keptTasks.map { MarkDot(hex: $0.colorHex, pattern: $0.markPatternKind) }
            return DayMarks(
                dots: bookmarkDot + habitDots,
                skipOnly: habitDots.isEmpty && bookmarkDot.isEmpty && !skippedFocused.isEmpty
            )
        }
    }
}

struct MarkDot: Equatable {
    var hex: String
    var pattern: MarkPattern
    /// Theme black/white day bookmark; not a habit color.
    var isBookmark: Bool = false

    static let bookmark = MarkDot(hex: "", pattern: .solid, isBookmark: true)
}

struct DayMarks {
    var dots: [MarkDot]
    var skipOnly: Bool

    /// Habit-colored dots only (excludes the theme bookmark mark).
    var habitDots: [MarkDot] { dots.filter { !$0.isBookmark } }
    var hasBookmark: Bool { dots.contains(where: \.isBookmark) }
}

enum CalendarDotStyle {
    case kept
    case missed
}
