import SwiftUI

struct DayStatusChip: View {
    var text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(AppTypography.secondary(11, weight: .semibold))
            .foregroundStyle(tint)
    }
}
