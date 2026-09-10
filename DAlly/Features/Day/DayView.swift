import SwiftUI
import SwiftData

struct DayView: View {
    var day: Date
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyTask.hour) private var tasks: [DailyTask]
    @Query private var logs: [TaskDayLog]
    @State private var stopTarget: DailyTask?
    @State private var confirmStop = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let sections = DaySectioningService.sections(
                day: day,
                tasks: tasks,
                logs: logs,
                now: context.date
            )
            let kind = DaySectioningService.kind(of: day, now: context.date)
            let canResolve = kind != .future
            let hero = kind == .today ? heroPair(in: sections) : nil

            Group {
                if sections.isEmpty {
                    VStack(spacing: 12) {
                        if kind == .today, WeekReview.isSunday(context.date) {
                            WeekReviewBanner {
                                router.openCalendar()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        EmptyDayView {
                            router.openEditor(taskId: nil)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if kind == .today, WeekReview.isSunday(context.date) {
                                WeekReviewBanner {
                                    router.openCalendar()
                                }
                            }

                            if let hero {
                                TodayFocusCard(
                                    task: hero.task,
                                    section: hero.section,
                                    day: day,
                                    onDone: { markKept(hero.task) },
                                    onSkip: { skip(hero.task) },
                                    onOpenActions: { router.openTaskActions(taskId: hero.task.id, day: day) }
                                )
                            }

                            ForEach(sections) { section in
                                let rows = section.tasks.filter { $0.id != hero?.task.id }
                                if !rows.isEmpty {
                                    DaySectionHeader(title: section.id.title(isToday: kind == .today))
                                    ForEach(rows, id: \.id) { task in
                                        TaskRowView(
                                            task: task,
                                            day: day,
                                            section: section.id,
                                            status: DayLogService.status(taskId: task.id, day: day, logs: logs),
                                            canResolve: canResolve,
                                            onToggleKept: { markKept(task) },
                                            onSkip: { skip(task) },
                                            onClear: { clear(task) },
                                            onOpenActions: { router.openTaskActions(taskId: task.id, day: day) },
                                            onStop: {
                                                stopTarget = task
                                                confirmStop = true
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 88)
                    }
                }
            }
        }
        .alert(AppCopy.stopTitle, isPresented: $confirmStop) {
            Button("Stop", role: .destructive) {
                if let stopTarget { stop(stopTarget) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AppCopy.stopBody)
        }
    }

    private func heroPair(in sections: [DaySection]) -> (task: DailyTask, section: DaySectionID)? {
        let order: [DaySectionID] = [.pastDue, .nextHour, .later]
        for id in order {
            if let task = sections.first(where: { $0.id == id })?.tasks.first {
                return (task, id)
            }
        }
        return nil
    }

    private func markKept(_ task: DailyTask) {
        let logDay = day.startOfLocalDay
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            DayLogService.markKept(taskId: task.id, day: logDay, in: modelContext)
        }
        Haptics.markDone()
    }

    private func skip(_ task: DailyTask) {
        let logDay = day.startOfLocalDay
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            DayLogService.markSkipped(taskId: task.id, day: logDay, in: modelContext)
        }
        Haptics.skip()
    }

    private func clear(_ task: DailyTask) {
        let logDay = day.startOfLocalDay
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            DayLogService.clearLog(taskId: task.id, day: logDay, in: modelContext)
        }
        Haptics.undo()
    }

    private func stop(_ task: DailyTask) {
        task.isStopped = true
        task.updatedAt = Date()
        try? modelContext.save()
        NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
        Haptics.delete()
    }
}

private struct TodayFocusCard: View {
    var task: DailyTask
    var section: DaySectionID
    var day: Date
    var onDone: () -> Void
    var onSkip: () -> Void
    var onOpenActions: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var color: Color { Color(hex: task.colorHex) }

    private var kicker: String {
        switch section {
        case .pastDue: "Past due"
        case .nextHour: "Up next"
        default: "Later"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpenActions) {
                VStack(alignment: .leading, spacing: 14) {
                    Text(kicker)
                        .font(AppTypography.captionSemibold)
                        .foregroundStyle(section == .pastDue ? AppColors.warning : AppColors.aqua)
                    HStack(alignment: .firstTextBaseline) {
                        Text(task.name)
                            .font(AppTypography.heroTitle)
                            .foregroundStyle(AppColors.textPrimary(scheme))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text(task.rowTimeLabel)
                            .font(AppTypography.heroTime.monospacedDigit())
                            .foregroundStyle(color)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button(action: onDone) {
                    Text("Mark done")
                        .font(AppTypography.button)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(color.contrastingForeground())
                        .background(color, in: Capsule())
                }
                .buttonStyle(.plain)
                Button(action: onSkip) {
                    Text("Skip")
                        .font(AppTypography.button)
                        .frame(width: 72)
                        .padding(.vertical, 12)
                        .foregroundStyle(AppColors.textPrimary(scheme))
                        .background(AppColors.rowFill(scheme), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(scheme == .dark ? 0.18 : 0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(color.opacity(0.45), lineWidth: 1)
                }
        }
    }
}
