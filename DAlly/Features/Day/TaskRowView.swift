import SwiftUI
import SwiftData

struct TaskRowView: View {
    let task: DailyTask
    let day: Date
    let section: DaySectionID
    let status: DayLogStatus?
    let canResolve: Bool

    var onToggleKept: () -> Void
    var onSkip: () -> Void
    var onClear: () -> Void
    var onOpenActions: () -> Void
    var onStop: () -> Void

    @Environment(\.colorScheme) private var scheme

    private var taskColor: Color { Color(hex: task.colorHex) }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(taskColor)
                .frame(width: 4)
                .padding(.vertical, 10)

            // Button (not onTapGesture) so taps fire immediately even with contextMenu.
            Button(action: onOpenActions) {
                HStack(alignment: .center, spacing: 12) {
                    TaskColorDot(hex: task.colorHex, pattern: task.markPatternKind, size: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(task.name)
                                .font(AppTypography.taskName)
                                .foregroundStyle(AppColors.textPrimary(scheme))
                            PriorityBadge(level: task.priorityLevel)
                        }
                        if !task.notes.isEmpty {
                            Text(task.notes)
                                .font(AppTypography.notes)
                                .foregroundStyle(AppColors.textSecondary(scheme))
                                .lineLimit(1)
                        }
                        statusLabel
                    }

                    Spacer(minLength: 8)

                    Text(task.rowTimeLabel)
                        .font(AppTypography.time.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary(scheme))
                }
                .padding(.leading, 10)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                if canResolve {
                    if status != .kept {
                        Button("Mark done", action: onToggleKept)
                    }
                    if status != .skipped {
                        Button("Skip today", action: onSkip)
                            .accessibilityLabel("Skip \(task.name) today")
                    }
                    if status != nil {
                        Button("Clear", action: onClear)
                    }
                } else {
                    Text(AppCopy.futureResolve)
                }
                Button("Task settings", action: onOpenActions)
                if task.isStopped == false {
                    Button("Stop reminding", role: .destructive, action: onStop)
                }
            }

            ConfirmDoneButton(
                color: taskColor,
                status: status,
                enabled: canResolve,
                action: {
                    if status == nil {
                        onToggleKept()
                    } else {
                        onClear()
                    }
                }
            )
            .padding(.trailing, 12)
            .padding(.leading, 4)
            .accessibilityLabel(checkboxLabel)
        }
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.rowFill(scheme))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(taskColor.opacity(scheme == .dark ? 0.28 : 0.22), lineWidth: 1)
                }
        }
        .sectionOpacity(section.opacity)
        // Force identity refresh when log status changes (missed → kept).
        .id("\(task.id.uuidString)-\(status?.rawValue ?? "open")-\(section.rawValue)")
        .accessibilityHint(task.schedule == .flexibleUntil ? "\(task.name), before \(TimeDisplay.clock(hour: task.windowEndHour, minute: task.windowEndMinute))" : "")
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var statusLabel: some View {
        // Prefer live log status so the chip updates immediately when marking
        // kept/skipped (section can lag during LazyVStack identity reuse).
        switch status {
        case .kept:
            DayStatusChip(text: "Kept", tint: taskColor)
        case .skipped:
            DayStatusChip(text: "Skipped", tint: AppColors.textSecondary(scheme))
        case nil:
            switch section {
            case .pastDue:
                DayStatusChip(text: "Past due", tint: AppColors.warning)
            case .missed:
                DayStatusChip(text: "Missed", tint: AppColors.danger(scheme))
            case .nextHour, .later:
                if task.schedule == .flexibleUntil {
                    DayStatusChip(
                        text: "Until \(TimeDisplay.clock(hour: task.windowEndHour, minute: task.windowEndMinute))",
                        tint: AppColors.textTertiary(scheme)
                    )
                }
            case .kept, .skipped, .scheduled:
                EmptyView()
            }
        }
    }

    private var checkboxLabel: String {
        if status == .kept { return "Mark \(task.name) not done" }
        if status == .skipped { return "Clear skip for \(task.name)" }
        if !canResolve { return AppCopy.futureResolve }
        return "Mark \(task.name) done"
    }
}
