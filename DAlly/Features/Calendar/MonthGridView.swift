import SwiftUI

struct MonthGridView: View {
    var month: Date
    var selectedDay: Date?
    var tasks: [DailyTask]
    var logs: [TaskDayLog]
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
                                cellHeight: cellHeight
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
        if day.startOfLocalDay > Date().startOfLocalDay {
            return DayMarks(dots: [], skipOnly: false)
        }
        let key = day.localDayKey
        let dayLogs = logs.filter { $0.dayKey == key }
        let kept = dayLogs.filter { $0.dayLogStatus == .kept }
        let skipped = dayLogs.filter { $0.dayLogStatus == .skipped }
        let byId = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let keptTasks = kept.compactMap { byId[$0.taskId] }
            .sorted { a, b in
                let da = a.dueDate(on: day)
                let db = b.dueDate(on: day)
                if da != db { return da < db }
                return a.name < b.name
            }
        let dots = keptTasks.map { MarkDot(hex: $0.colorHex, pattern: $0.markPatternKind) }
        return DayMarks(dots: dots, skipOnly: dots.isEmpty && !skipped.isEmpty)
    }
}

struct MarkDot: Equatable {
    var hex: String
    var pattern: MarkPattern
}

struct DayMarks {
    var dots: [MarkDot]
    var skipOnly: Bool
}
