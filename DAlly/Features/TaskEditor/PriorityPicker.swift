import SwiftUI

struct PriorityPicker: View {
    @Binding var priority: PriorityLevel

    var body: some View {
        Picker("Priority", selection: $priority) {
            ForEach(PriorityLevel.allCases) { level in
                Text(level.displayName).tag(level)
            }
        }
        .pickerStyle(.segmented)
    }
}
