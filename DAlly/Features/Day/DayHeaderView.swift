import SwiftUI

struct DayHeaderView: View {
    var day: Date
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onJumpToday: () -> Void
    @Environment(\.colorScheme) private var scheme

    private var isToday: Bool {
        Date.isSameLocalDay(day, Date())
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }

                Spacer(minLength: 0)

                Text(isToday ? "Today" : TimeDisplay.weekdayMonthDay(day))
                    .font(AppTypography.screenTitle)
                    .foregroundStyle(AppColors.textPrimary(scheme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
            }

            if !isToday {
                Button(AppCopy.jumpToToday, action: onJumpToday)
                    .font(AppTypography.captionSemibold)
                    .foregroundStyle(AppColors.aquaInk(scheme))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .tint(AppColors.textPrimary(scheme))
    }
}
