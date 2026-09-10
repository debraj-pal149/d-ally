import Foundation
import SwiftUI

struct TaskActionPrompt: Identifiable, Equatable {
    let id: UUID
    let taskId: UUID
    let day: Date

    init(taskId: UUID, day: Date) {
        self.id = UUID()
        self.taskId = taskId
        self.day = day.startOfLocalDay
    }
}

@Observable
final class DeepLinkRouter {
    var selectedTab: AppTab = .day
    var selectedDay: Date = Date().startOfLocalDay
    var calendarMonth: Date = Date().startOfLocalDay
    var focusTaskId: UUID?
    var taskActionPrompt: TaskActionPrompt?
    var showTaskEditor: Bool = false
    var editingTaskId: UUID?
    var showNotificationPriming: Bool = false
    var pendingKeepRemindingTaskId: UUID?
    /// When true, the next `.active` scene phase should not wipe navigation (notification deep link).
    var suppressNextActiveReset: Bool = false

    func jumpToToday() {
        selectedDay = Date().startOfLocalDay
        calendarMonth = Date().startOfLocalDay
        selectedTab = .day
    }

    func resetToTodayViews() {
        selectedDay = Date().startOfLocalDay
        calendarMonth = Date().startOfLocalDay
    }

    func openTaskActions(taskId: UUID, day: Date) {
        // Do not mutate selectedDay here — the sheet carries its own day, and rewriting
        // the pager day (or a later reset-to-today) was bouncing past-day taps back to today.
        focusTaskId = taskId
        taskActionPrompt = TaskActionPrompt(taskId: taskId, day: day)
    }

    func openCalendar(month: Date = Date()) {
        selectedTab = .calendar
        calendarMonth = month.startOfLocalDay
    }

    func apply(url: URL) {
        suppressNextActiveReset = true
        guard url.scheme == "dally" else { return }
        switch url.host {
        case "day":
            selectedTab = .day
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if let dateStr = items.first(where: { $0.name == "date" })?.value,
               let date = Date.date(fromDayKey: dateStr) {
                selectedDay = date.startOfLocalDay
                calendarMonth = date.startOfLocalDay
            }
            if let idStr = items.first(where: { $0.name == "taskId" })?.value,
               let id = UUID(uuidString: idStr) {
                focusTaskId = id
                let prompt = items.first(where: { $0.name == "prompt" })?.value
                if prompt == "1" {
                    taskActionPrompt = TaskActionPrompt(taskId: id, day: selectedDay)
                }
            }
        case "calendar":
            openCalendar()
        case "settings":
            selectedTab = .settings
        case "editor":
            selectedTab = .day
            openEditor(taskId: nil)
        default:
            break
        }
    }

    func openEditor(taskId: UUID?) {
        editingTaskId = taskId
        showTaskEditor = true
    }
}
