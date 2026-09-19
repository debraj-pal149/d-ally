import SwiftUI

struct RepeatPicker: View {
    @Binding var option: RepeatOption
    @Binding var weeklyWeekdaysMask: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach([RepeatOption.daily, .every2Days, .every3Days, .weekly]) { item in
                cadenceRow(item)
            }

            if option == .weekly {
                weekdayChips
                    .padding(.top, 4)
            }
        }
    }

    private func cadenceRow(_ item: RepeatOption) -> some View {
        let selected = option == item
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                option = item
                if item == .weekly, weeklyWeekdaysMask == 0 {
                    weeklyWeekdaysMask = WeeklyWeekdays.todayMask()
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? AppColors.aquaInk(scheme) : AppColors.textTertiary(scheme))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(AppTypography.button)
                        .foregroundStyle(AppColors.textPrimary(scheme))
                    if item == .weekly, selected {
                        Text(WeeklyWeekdays.summary(mask: weeklyWeekdaysMask))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary(scheme))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var weekdayChips: some View {
        let ordered = orderedWeekdays()
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
            spacing: 8
        ) {
            ForEach(ordered) { day in
                let on = WeeklyWeekdays.contains(mask: weeklyWeekdaysMask, weekday: day.rawValue)
                Button {
                    let next = WeeklyWeekdays.toggling(mask: weeklyWeekdaysMask, weekday: day.rawValue)
                    // Keep at least one day selected.
                    if next != 0 {
                        weeklyWeekdaysMask = next
                    }
                } label: {
                    Text(day.shortLabel)
                        .font(AppTypography.captionSemibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(on ? Color(hex: "#102026") : AppColors.textPrimary(scheme))
                        .background(on ? AppColors.aqua : AppColors.rowFill(scheme), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(on ? AppColors.aqua : AppColors.textTertiary(scheme).opacity(0.25), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .accessibilityLabel("Weekdays")
    }

    /// Locale-aware order starting at Calendar.firstWeekday.
    private func orderedWeekdays() -> [WeekdayChoice] {
        let first = Calendar.current.firstWeekday
        let all = WeekdayChoice.allCases
        let head = all.filter { $0.rawValue >= first }
        let tail = all.filter { $0.rawValue < first }
        return head + tail
    }
}
