import SwiftUI

struct WeeklyReviewSheet: View {
    let analysis: WeeklyReviewAnalysis
    let source: WeekReviewSource
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AppCanvas()
            ScrollView {
                VStack(spacing: 22) {
                    header
                    score
                    dayStrip
                    summaryCards
                    if !analysis.taskRhythms.isEmpty {
                        taskRhythms
                    }
                    Button {
                        close()
                    } label: {
                        Text("See calendar")
                            .font(AppTypography.button)
                            .foregroundStyle(Color(hex: "#071217"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppColors.aqua, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(30)
        .onAppear {
            Analytics.track("week_review_opened", ["source": source.rawValue])
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("YOUR WEEK")
                    .font(AppTypography.sectionHeader)
                    .tracking(1.6)
                    .foregroundStyle(AppColors.aquaInk(scheme))
                Text("Consistency, in color.")
                    .font(AppTypography.primary(25, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary(scheme))
                Text(weekRange)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary(scheme))
            }
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary(scheme))
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close weekly review")
        }
    }

    private var score: some View {
        HStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(AppColors.aqua.opacity(0.13), lineWidth: 13)
                Circle()
                    .trim(from: 0, to: max(0.012, Double(analysis.currentWeek.percentage) / 100))
                    .stroke(
                        AngularGradient(
                            colors: [AppColors.aqua, Color(hex: "#37E3AF"), Color(hex: "#D8EE45")],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: AppColors.aqua.opacity(0.28), radius: 10)
                VStack(spacing: 0) {
                    Text("\(analysis.currentWeek.percentage)")
                        .font(AppTypography.primary(34, weight: .bold))
                    Text("%")
                        .font(AppTypography.captionSemibold)
                        .foregroundStyle(AppColors.textSecondary(scheme))
                }
            }
            .frame(width: 126, height: 126)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(analysis.currentWeek.percentage) percent consistency this week")

            VStack(alignment: .leading, spacing: 8) {
                Text(analysis.currentWeek.scheduled == 0
                     ? "No marks yet"
                     : "Kept \(analysis.currentWeek.kept) of \(analysis.currentWeek.scheduled)")
                    .font(AppTypography.primary(20, weight: .semibold))
                Text(scoreDetail)
                    .font(AppTypography.footnote)
                    .foregroundStyle(AppColors.textSecondary(scheme))
                if let comparison = analysis.weekComparisonText {
                    Label(comparison, systemImage: comparisonIcon)
                        .font(AppTypography.captionSemibold)
                        .foregroundStyle(comparisonColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(comparisonColor.opacity(0.12), in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .dallyGlass(cornerRadius: 26)
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(AppColors.aqua.opacity(0.22), lineWidth: 1)
        }
    }

    private var dayStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kept each day")
                    .font(AppTypography.primary(16, weight: .semibold))
                Spacer()
                Text("kept / scheduled")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary(scheme))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(analysis.days) { day in
                        VStack(spacing: 4) {
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(AppTypography.captionSemibold)
                                .foregroundStyle(AppColors.textSecondary(scheme))
                            Text(day.date.formatted(.dateTime.day()))
                                .font(AppTypography.primary(16, weight: .semibold))
                            if day.scheduled > 0 {
                                Text("\(day.kept) / \(day.scheduled)")
                                    .font(AppTypography.captionSemibold)
                                    .foregroundStyle(day.kept > 0 ? Color(hex: "#071217") : AppColors.textSecondary(scheme))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(dayFill(day), in: Capsule())
                            } else {
                                Text("No marks")
                                    .font(AppTypography.secondary(10, weight: .medium))
                                    .foregroundStyle(AppColors.textTertiary(scheme))
                                    .padding(.vertical, 4)
                            }
                        }
                        .frame(width: 58, height: 82)
                        .background(AppColors.rowFill(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(dayAccessibility(day))
                    }
                }
            }
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "LAST WEEK",
                value: analysis.previousWeek.map { "\($0.percentage)%" } ?? "—",
                detail: analysis.previousWeek == nil ? "No earlier week yet" : "Previous rhythm",
                color: Color(hex: "#4B84ED")
            )
            metricCard(
                title: "THIS MONTH",
                value: "\(analysis.monthToDate.percentage)%",
                detail: "\(analysis.monthToDate.kept) of \(analysis.monthToDate.scheduled) kept",
                color: Color(hex: "#37E3AF")
            )
        }
    }

    private var taskRhythms: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task rhythm")
                .font(AppTypography.primary(18, weight: .semibold))
            VStack(spacing: 0) {
                ForEach(Array(analysis.taskRhythms.enumerated()), id: \.element.id) { index, rhythm in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: rhythm.colorHex))
                            .frame(width: 11, height: 11)
                            .shadow(color: Color(hex: rhythm.colorHex).opacity(0.55), radius: 5)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rhythm.name)
                                .font(AppTypography.taskName)
                                .lineLimit(1)
                            Text(rhythm.comparisonText ?? "Kept \(rhythm.kept) of \(rhythm.scheduled) this week")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary(scheme))
                        }
                        Spacer()
                        Text("\(rhythm.percentage)%")
                            .font(AppTypography.primary(16, weight: .semibold))
                            .foregroundStyle(Color(hex: rhythm.colorHex))
                    }
                    .padding(.vertical, 13)
                    if index < analysis.taskRhythms.count - 1 {
                        Divider().overlay(AppColors.separator(scheme).opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(AppColors.rowFill(scheme), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func metricCard(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AppTypography.sectionHeader)
                .tracking(1.1)
                .foregroundStyle(color)
            Text(value)
                .font(AppTypography.primary(25, weight: .bold))
            Text(detail)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary(scheme))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(color.opacity(0.2), lineWidth: 1)
        }
    }

    private var weekRange: String {
        let start = analysis.weekStart.formatted(.dateTime.month(.abbreviated).day())
        let end = analysis.weekEnd.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    private var scoreDetail: String {
        let skipped = analysis.currentWeek.skipped
        let missed = analysis.currentWeek.missed
        if skipped == 0 && missed == 0 { return "Every resolved task was kept." }
        return "\(skipped) skipped · \(missed) missed"
    }

    private var comparisonIcon: String {
        guard let previous = analysis.previousWeek else { return "minus" }
        if analysis.currentWeek.percentage > previous.percentage { return "arrow.up.right" }
        if analysis.currentWeek.percentage < previous.percentage { return "arrow.down.right" }
        return "arrow.right"
    }

    private var comparisonColor: Color {
        guard let previous = analysis.previousWeek else { return AppColors.textSecondary(scheme) }
        return analysis.currentWeek.percentage >= previous.percentage
            ? Color(hex: "#37E3AF")
            : Color(hex: "#FFB020")
    }

    private func dayFill(_ day: WeeklyReviewAnalysis.Day) -> Color {
        guard day.scheduled > 0 else { return .clear }
        if day.kept == day.scheduled { return Color(hex: "#D8EE45") }
        if day.kept > 0 { return AppColors.aqua }
        return AppColors.rowFill(scheme)
    }

    private func dayAccessibility(_ day: WeeklyReviewAnalysis.Day) -> String {
        let name = day.date.formatted(.dateTime.weekday(.wide))
        guard day.scheduled > 0 else { return "\(name), no completed tasks counted yet" }
        return "\(name), kept \(day.kept) of \(day.scheduled)"
    }

    private func close() {
        Analytics.track("week_review_closed", ["source": source.rawValue])
        dismiss()
    }
}
