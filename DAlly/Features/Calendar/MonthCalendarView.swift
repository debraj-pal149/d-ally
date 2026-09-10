import SwiftUI
import SwiftData

struct MonthCalendarView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var scheme
    @Query private var tasks: [DailyTask]
    @Query private var logs: [TaskDayLog]
    @State private var selectedDay: Date?
    @State private var showDetail = false

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
                        logs: logs
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
                        Text(AppCopy.calendarLegend)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textTertiary(scheme))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        legendChips
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
                    HStack(spacing: 6) {
                        PatternedMark(hex: task.colorHex, pattern: task.markPatternKind, size: 8)
                        Text(task.name)
                            .font(AppTypography.caption)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: task.colorHex).opacity(0.16), in: Capsule())
                    .overlay {
                        Capsule().stroke(Color(hex: task.colorHex).opacity(0.35), lineWidth: 1)
                    }
                }
            }
        }
    }
}
