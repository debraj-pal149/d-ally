import SwiftUI

struct OverdueReminderPicker: View {
    @Binding var mode: OverdueReminderMode

    var body: some View {
        Picker("If still open", selection: $mode) {
            ForEach(OverdueReminderMode.allCases) { item in
                Text(item.displayName).tag(item)
            }
        }
        .pickerStyle(.menu)
    }
}
