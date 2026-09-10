import SwiftUI

struct PriorityBadge: View {
    var level: PriorityLevel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if level == .high {
            Text("HIGH")
                .font(AppTypography.secondary(10, weight: .bold))
                .foregroundStyle(AppColors.textSecondary(scheme))
                .tracking(0.6)
        }
    }
}
