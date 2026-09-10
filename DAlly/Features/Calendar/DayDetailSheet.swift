import SwiftUI

struct DayDetailSheet: View {
    var day: Date
    var tasks: [DailyTask]
    var logs: [TaskDayLog]
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.id.title(isToday: Date.isSameLocalDay(day, Date()))) {
                        ForEach(section.tasks, id: \.id) { task in
                            HStack {
                                TaskColorDot(hex: task.colorHex, pattern: task.markPatternKind)
                                VStack(alignment: .leading) {
                                    Text(task.name)
                                    Text(statusText(task))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Button("Open in Day view") {
                    router.selectedDay = day.startOfLocalDay
                    router.selectedTab = .day
                    dismiss()
                }
            }
            .navigationTitle(TimeDisplay.weekdayMonthDay(day))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }

    private var sections: [DaySection] {
        DaySectioningService.sections(day: day, tasks: tasks, logs: logs)
    }

    private func statusText(_ task: DailyTask) -> String {
        switch DayLogService.status(taskId: task.id, day: day, logs: logs) {
        case .kept: return "Kept"
        case .skipped: return "Skipped"
        case nil:
            if DaySectioningService.kind(of: day) == .future { return "Scheduled" }
            if DaySectioningService.kind(of: day) == .past { return "Missed" }
            if task.dueDate(on: day) < Date() { return "Past due" }
            return "Open"
        }
    }
}
