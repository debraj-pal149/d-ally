import SwiftUI

struct EmptyDayView: View {
    var onAdd: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)
            VStack(spacing: 12) {
                Text(AppCopy.emptyHeadline)
                    .font(AppTypography.emptyTitle)
                    .foregroundStyle(AppColors.textPrimary(scheme))
                Text(AppCopy.emptyBody)
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColors.textSecondary(scheme))
                    .lineLimit(1)
                Button(action: onAdd) {
                    Text(AppCopy.addDailyReminder)
                        .font(AppTypography.button)
                        .foregroundStyle(Color(hex: "#102026"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(AppColors.aqua, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppColors.coolGlass(scheme))
                    }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
