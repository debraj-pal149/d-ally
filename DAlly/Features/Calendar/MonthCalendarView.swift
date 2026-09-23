import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Query private var tasks: [DailyTask]
    @Query private var logs: [TaskDayLog]
    @State private var selectedDay: Date?
    @State private var showDetail = false
    @State private var marksMode: CalendarMarksMode = .kept
    @State private var focusedTaskIds: Set<UUID> = []

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            ZStack {
                AppCanvas()
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                    MonthGridView(
                        month: router.calendarMonth,
                        selectedDay: selectedDay,
                        tasks: tasks,
                        logs: logs,
                        marksMode: marksMode,
                        focusedTaskIds: focusedTaskIds
                    ) { day in
                        selectedDay = day
                        showDetail = true
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(AppColors.rowFill(scheme).opacity(0.55))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(AppColors.aqua.opacity(0.16), lineWidth: 1)
                            }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(marksMode.legend)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textTertiary(scheme))
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 8)
                            marksModeToggle
                        }
                        legendChips
                        Text(AppCopy.calendarFocusHint)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary(scheme))
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(isPresented: $showDetail) {
                if let selectedDay {
                    DayDetailSheet(day: selectedDay, tasks: tasks, logs: logs)
                }
            }
        }
    }

    private var marksModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(CalendarMarksMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        marksMode = mode
                    }
                } label: {
                    Text(mode.title)
                        .font(AppTypography.captionSemibold)
                        .foregroundStyle(
                            marksMode == mode
                                ? AppColors.textPrimary(scheme)
                                : AppColors.textTertiary(scheme)
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            if marksMode == mode {
                                Capsule().fill(AppColors.rowFill(scheme))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(AppColors.rowFill(scheme).opacity(0.55), in: Capsule())
        .accessibilityLabel("Calendar marks mode")
    }

    private var header: some View {
        HStack {
            Button {
                router.calendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: router.calendarMonth) ?? router.calendarMonth
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            Spacer()
            Text(TimeDisplay.monthYear(router.calendarMonth))
                .font(AppTypography.screenTitle)
            Spacer()
            Button {
                router.calendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: router.calendarMonth) ?? router.calendarMonth
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            Button("Today") {
                let today = Date().startOfLocalDay
                router.calendarMonth = today
                selectedDay = today
                showDetail = true
            }
            .font(AppTypography.captionSemibold)
            .foregroundStyle(AppColors.aqua)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.aqua.opacity(0.16), in: Capsule())
        }
        .padding(.horizontal, 6)
        .dallyGlass(cornerRadius: 22)
        .tint(AppColors.textPrimary(scheme))
    }

    private var legendChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tasks.filter { !$0.isStopped }, id: \.id) { task in
                    let selected = focusedTaskIds.contains(task.id)
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            if selected {
                                focusedTaskIds.remove(task.id)
                            } else {
                                focusedTaskIds.insert(task.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: task.colorHex))
                            }
                            if marksMode == .missed {
                                Circle()
                                    .strokeBorder(Color(hex: task.colorHex), lineWidth: 1.5)
                                    .frame(width: 8, height: 8)
                            } else {
                                PatternedMark(hex: task.colorHex, pattern: task.markPatternKind, size: 8)
                            }
                            Text(task.name)
                                .font(AppTypography.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: task.colorHex).opacity(selected ? 0.28 : 0.16), in: Capsule())
                        .overlay {
                            Capsule().stroke(Color(hex: task.colorHex).opacity(selected ? 0.7 : 0.35), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(task.name)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}
