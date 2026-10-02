import SwiftUI

struct DayDetailSheet: View {
    var day: Date
    var tasks: [DailyTask]
    var logs: [TaskDayLog]
    var bookmarks: [DayBookmark] = []
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private var dayBookmarks: [DayBookmark] {
        DayBookmark.live(on: day, in: bookmarks)
    }

    var body: some View {
        NavigationStack {
            List {
                if !dayBookmarks.isEmpty {
                    Section(AppCopy.calendarDayBookmarks) {
                        ForEach(dayBookmarks, id: \.id) { bookmark in
                            Button {
                                let id = bookmark.id
                                dismiss()
                                DispatchQueue.main.async {
                                    router.openBookmarkEditor(bookmarkId: id, day: day)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(scheme == .dark ? Color.white : Color.black)
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.title)
                                            .foregroundStyle(AppColors.textPrimary(scheme))
                                        if !bookmark.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text(bookmark.notes)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

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
