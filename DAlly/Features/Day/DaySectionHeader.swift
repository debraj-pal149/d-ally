import SwiftUI

struct DaySectionHeader: View {
    var title: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(AppColors.aqua)
                .frame(width: 14, height: 3)
            Text(title)
                .font(AppTypography.sectionHeader)
                .foregroundStyle(AppColors.textSecondary(scheme))
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
