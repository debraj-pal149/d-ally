import SwiftUI
import SwiftData

struct CompletionPromptSheet: View {
    var taskId: UUID
    var day: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Query private var tasks: [DailyTask]
    @Query private var logs: [TaskDayLog]

    @State private var contentHeight: CGFloat = 240

    private var task: DailyTask? { tasks.first { $0.id == taskId } }

    private var status: DayLogStatus? {
        DayLogService.status(taskId: taskId, day: day, logs: logs)
    }

    private var dayKind: DayKind {
        DaySectioningService.kind(of: day)
    }

    /// Past + today can mark kept/skip/clear. Future is settings only.
    private var canResolve: Bool { dayKind != .future }

    private var isToday: Bool { dayKind == .today }

    /// Follow-up remind only makes sense for an open task on today.
    private var showRemindAgain: Bool {
        guard let task, isToday, status == nil else { return false }
        return task.dueDate(on: day) < Date()
    }

    var body: some View {
        Group {
            if let task {
                sheetBody(task)
            } else {
                Text("Reminder deleted")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.textSecondary(scheme))
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { updateHeight($0) }
            }
        }
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground {
            sheetChrome
        }
    }

    @ViewBuilder
    private var sheetChrome: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func sheetBody(_ task: DailyTask) -> some View {
        let color = Color(hex: task.colorHex)

        VStack(alignment: .leading, spacing: 10) {
            header(task: task, color: color)

            if canResolve {
                if status != .kept {
                    Button {
                        let logDay = day.startOfLocalDay
                        DayLogService.markKept(taskId: task.id, day: logDay, in: modelContext)
                        Haptics.markDone()
                        dismiss()
                    } label: {
                        Text("Mark done")
                            .font(AppTypography.button)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .foregroundStyle(color.contrastingForeground())
                            .background(color, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                let secondaryActions = secondaryActionModels(for: task)
                if !secondaryActions.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(secondaryActions.enumerated()), id: \.offset) { index, item in
                            if index > 0 {
                                Divider().opacity(0.35)
                            }
                            Button(action: item.action) {
                                HStack(spacing: 12) {
                                    Image(systemName: item.systemImage)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(item.tint)
                                        .frame(width: 22)
                                    Text(item.title)
                                        .font(AppTypography.button)
                                        .foregroundStyle(AppColors.textPrimary(scheme))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .dallyGlass(cornerRadius: 18)
                }
            }

            Button {
                let id = task.id
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    router.openEditor(taskId: id)
                }
            } label: {
                Text("Open task settings")
                    .font(AppTypography.captionSemibold)
                    .foregroundStyle(AppColors.aquaInk(scheme))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            updateHeight(newHeight)
        }
    }

    private func updateHeight(_ measured: CGFloat) {
        let next = max(measured + 10, 120)
        guard abs(contentHeight - next) > 0.5 else { return }
        contentHeight = next
    }

    private func header(task: DailyTask, color: Color) -> some View {
        HStack(alignment: .center, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 4, height: 36)

            TaskColorDot(hex: task.colorHex, pattern: task.markPatternKind, size: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.name)
                    .font(AppTypography.taskName)
                    .foregroundStyle(AppColors.textPrimary(scheme))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if !isToday {
                        Text(TimeDisplay.weekdayMonthDay(day))
                            .font(AppTypography.captionSemibold)
                            .foregroundStyle(AppColors.textSecondary(scheme))
                            .lineLimit(1)
                    }
                    Text(scheduleLine(task))
                        .font(AppTypography.time.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary(scheme))
                    DayStatusChip(text: statusHeadline, tint: statusTint(color))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .dallyGlass(cornerRadius: 18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(scheme == .dark ? 0.28 : 0.22), lineWidth: 1)
        }
    }

    private struct SecondaryAction {
        var title: String
        var systemImage: String
        var tint: Color
        var action: () -> Void
    }

    private func secondaryActionModels(for task: DailyTask) -> [SecondaryAction] {
        var items: [SecondaryAction] = []
        if status != .skipped {
            items.append(
                SecondaryAction(
                    title: isToday ? "Skip today" : "Skip day",
                    systemImage: "forward.fill",
                    tint: AppColors.warning
                ) {
                    let logDay = day.startOfLocalDay
                    DayLogService.markSkipped(taskId: task.id, day: logDay, in: modelContext)
                    Haptics.skip()
                    dismiss()
                }
            )
        }
        if status != nil {
            items.append(
                SecondaryAction(title: "Clear", systemImage: "arrow.uturn.backward", tint: AppColors.textSecondary(scheme)) {
                    let logDay = day.startOfLocalDay
                    DayLogService.clearLog(taskId: task.id, day: logDay, in: modelContext)
                    Haptics.undo()
                    dismiss()
                }
            )
        }
        if showRemindAgain {
            items.append(
                SecondaryAction(title: "Remind me again", systemImage: "bell.badge", tint: AppColors.aquaInk(scheme)) {
                    Task {
                        await NotificationSchedulingService.shared.scheduleKeepReminding(task: task, day: day)
                    }
                    dismiss()
                }
            )
        }
        return items
    }

    private func statusTint(_ taskColor: Color) -> Color {
        switch status {
        case .kept: return taskColor
        case .skipped: return AppColors.textSecondary(scheme)
        case nil:
            if dayKind == .past { return AppColors.danger(scheme) }
            if showRemindAgain { return AppColors.warning }
            return AppColors.aquaInk(scheme)
        }
    }

    private var statusHeadline: String {
        switch status {
        case .kept: return "Kept"
        case .skipped: return "Skipped"
        case nil:
            switch dayKind {
            case .future: return "Scheduled"
            case .past: return "Missed"
            case .today: return showRemindAgain ? "Past due" : "Open"
            }
        }
    }

    private func scheduleLine(_ task: DailyTask) -> String {
        switch task.schedule {
        case .fixedTime:
            return TimeDisplay.clock(hour: task.hour, minute: task.minute)
        case .flexibleUntil:
            return "Before \(TimeDisplay.clock(hour: task.windowEndHour, minute: task.windowEndMinute))"
        }
    }
}
