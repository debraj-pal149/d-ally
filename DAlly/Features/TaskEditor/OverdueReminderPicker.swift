import SwiftUI

struct OverdueReminderPicker: View {
    @Binding var mode: OverdueReminderMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("If still open", selection: $mode) {
                ForEach(OverdueReminderMode.allCases) { item in
                    Text(item.displayName).tag(item)
                }
            }
            .pickerStyle(.menu)

            Text(mode.helper)
                .font(AppTypography.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
