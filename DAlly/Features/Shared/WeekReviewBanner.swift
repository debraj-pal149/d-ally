import SwiftUI

struct WeekReviewBanner: View {
    var onOpenCalendar: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: onOpenCalendar) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppCopy.weekReviewBannerTitle)
                        .font(AppTypography.taskName)
                        .foregroundStyle(AppColors.textPrimary(scheme))
                    Text(AppCopy.weekReviewBannerBody)
                        .font(AppTypography.footnote)
                        .foregroundStyle(AppColors.textSecondary(scheme))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                Spacer(minLength: 8)
                Text(AppCopy.weekReviewBannerCTA)
                    .font(AppTypography.captionSemibold)
                    .foregroundStyle(AppColors.aquaInk(scheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dallyGlass(cornerRadius: 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.aqua.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the calendar tab")
    }
}

enum WeekReview {
    /// Gregorian weekday: Sunday == 1
    static func isSunday(_ date: Date = Date()) -> Bool {
        Calendar.current.component(.weekday, from: date) == 1
    }
}
