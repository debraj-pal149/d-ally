import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct TaskEditorView: View {
    var taskId: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkRouter.self) private var router
    @Query private var tasks: [DailyTask]
    @Query private var logs: [TaskDayLog]

    @AppStorage(AppStorageKey.defaultOverdueMode) private var defaultOverdueMode = AppDefaults.defaultOverdueMode
    @AppStorage(AppStorageKey.hasRequestedNotificationPermission) private var hasRequestedPermission = false

    @State private var name = ""
    @State private var notes = ""
    @State private var kind: ScheduleKind = .fixedTime
    @State private var hour = 9
    @State private var minute = 0
    @State private var windowEndHour = 22
    @State private var windowEndMinute = 0
    @State private var priority: PriorityLevel = .normal
    @State private var colorHex = TaskColorPalette.all[0].hex
    @State private var markPattern: MarkPattern = .solid
    @State private var repeatOption: RepeatOption = .daily
    @State private var weeklyWeekdaysMask = WeeklyWeekdays.todayMask()
    @State private var untilStopped = true
    @State private var endDate = Date().startOfLocalDay
    @State private var overdueMode: OverdueReminderMode = .onceAfter10Minutes
    @State private var notificationsEnabled = true
    @State private var confirmDelete = false
    @State private var confirmStop = false
    @State private var didLoad = false

    private var existing: DailyTask? {
        guard let taskId else { return nil }
        return tasks.first { $0.id == taskId }
    }

    private var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if repeatOption == .weekly, weeklyWeekdaysMask == 0 {
            return false
        }
        if kind == .flexibleUntil {
            return DailyTask.flexibleWindowValid(
                nudgeHour: hour,
                nudgeMinute: minute,
                endHour: windowEndHour,
                endMinute: windowEndMinute
            )
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section {
                    ScheduleKindPicker(kind: $kind)
                    if kind == .fixedTime {
                        TimeOfDayPicker(title: "Remind me at", hour: $hour, minute: $minute)
                    } else {
                        FlexibleWindowFields(
                            completeHour: $windowEndHour,
                            completeMinute: $windowEndMinute,
                            nudgeHour: $hour,
                            nudgeMinute: $minute
                        )
                    }
                }

                Section("Repeat") {
                    RepeatPicker(option: $repeatOption, weeklyWeekdaysMask: $weeklyWeekdaysMask)
                }

                Section {
                    ColorSwatchPicker(hex: $colorHex)
                }

                Section("Priority") {
                    PriorityPicker(priority: $priority)
                }

                Section("Duration") {
                    DurationPicker(untilStopped: $untilStopped, endDate: $endDate)
                }

                Section("If still open") {
                    OverdueReminderPicker(mode: $overdueMode)
                }

                Section {
                    NotesEditorField(notes: $notes)
                }

                Section {
                    Toggle("Alerts for this reminder", isOn: $notificationsEnabled)
                    NotificationPermissionFooter()
                }

                if existing != nil {
                    Section {
                        Button("Stop reminding", role: .destructive) { confirmStop = true }
                        Button("Delete reminder", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(taskId == nil ? "New reminder" : "Edit reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: loadIfNeeded)
            .onChange(of: kind) { _, new in
                if new == .flexibleUntil && hour == 9 && minute == 0 && existing == nil {
                    windowEndHour = 22
                    windowEndMinute = 0
                    hour = 18
                    minute = 0
                }
            }
            .alert(AppCopy.deleteTitle, isPresented: $confirmDelete) {
                Button("Delete", role: .destructive, action: deleteTask)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(AppCopy.deleteBody)
            }
            .alert(AppCopy.stopTitle, isPresented: $confirmStop) {
                Button("Stop", role: .destructive, action: stopTask)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(AppCopy.stopBody)
            }
        }
        .presentationDetents([.large])
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        if let task = existing {
            name = task.name
            notes = task.notes
            kind = task.schedule
            hour = task.hour
            minute = task.minute
            windowEndHour = task.windowEndHour
            windowEndMinute = task.windowEndMinute
            priority = task.priorityLevel
            colorHex = task.colorHex
            markPattern = task.markPatternKind
            repeatOption = task.repeatOption
            weeklyWeekdaysMask = task.weeklyWeekdaysMask == 0
                ? WeeklyWeekdays.todayMask()
                : task.weeklyWeekdaysMask
            untilStopped = task.endDate == nil
            endDate = task.endDate ?? Date().startOfLocalDay
            overdueMode = task.overdueMode
            notificationsEnabled = task.notificationsEnabled
        } else {
            let assignment = ColorAssignmentService.nextUnused(existing: tasks)
            colorHex = assignment.colorHex
            markPattern = assignment.pattern
            overdueMode = OverdueReminderMode(rawValue: defaultOverdueMode) ?? .onceAfter10Minutes
            weeklyWeekdaysMask = WeeklyWeekdays.todayMask()
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isCreate = existing == nil
        let task = existing ?? DailyTask(name: trimmed, colorHex: colorHex, markPattern: markPattern)
        if existing == nil {
            modelContext.insert(task)
        }
        task.name = trimmed
        task.notes = notes
        task.schedule = kind
        task.hour = hour
        task.minute = minute
        if kind == .flexibleUntil {
            task.windowEndHour = windowEndHour
            task.windowEndMinute = windowEndMinute
        } else {
            task.windowEndHour = 0
            task.windowEndMinute = 0
        }
        task.priorityLevel = priority
        task.colorHex = colorHex
        task.markPatternKind = markPattern
        task.repeatOption = repeatOption
        task.weeklyWeekdaysMask = repeatOption == .weekly ? weeklyWeekdaysMask : 0
        if repeatOption == .every2Days || repeatOption == .every3Days {
            task.repeatIntervalDays = repeatOption.intervalDays
        }
        task.endDate = untilStopped ? nil : endDate.startOfLocalDay
        task.overdueMode = overdueMode
        task.notificationsEnabled = notificationsEnabled
        task.updatedAt = Date()
        task.isStopped = false
        try? modelContext.save()
        NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
        dismiss()

        if isCreate {
            Task {
                let state = await NotificationPermissionService.shared.currentState()
                if state == .notDetermined {
                    await MainActor.run { router.showNotificationPriming = true }
                }
            }
        }
    }

    private func deleteTask() {
        guard let task = existing else { return }
        Haptics.delete()
        DayLogService.deleteLogs(for: task.id, in: modelContext)
        modelContext.delete(task)
        try? modelContext.save()
        NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
        dismiss()
    }

    private func stopTask() {
        guard let task = existing else { return }
        task.isStopped = true
        task.updatedAt = Date()
        try? modelContext.save()
        NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
        Haptics.delete()
        dismiss()
    }
}

private struct NotificationPermissionFooter: View {
    @State private var state: NotificationAuthState = .notDetermined

    var body: some View {
        Group {
            if state == .denied {
                Button("Enable in Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .font(.footnote)
        .task { state = await NotificationPermissionService.shared.currentState() }
    }
}
