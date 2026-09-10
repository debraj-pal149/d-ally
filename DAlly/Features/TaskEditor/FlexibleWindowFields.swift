import SwiftUI

struct FlexibleWindowFields: View {
    @Binding var completeHour: Int
    @Binding var completeMinute: Int
    @Binding var nudgeHour: Int
    @Binding var nudgeMinute: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TimeOfDayPicker(title: "Complete by", hour: $completeHour, minute: $completeMinute)
            TimeOfDayPicker(title: "First remind me at", hour: $nudgeHour, minute: $nudgeMinute)
            Text("Past due after the end time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
