import SwiftUI

struct ScheduleKindPicker: View {
    @Binding var kind: ScheduleKind

    var body: some View {
        Picker("Schedule", selection: $kind) {
            Text("Specific time").tag(ScheduleKind.fixedTime)
            Text("Finish by").tag(ScheduleKind.flexibleUntil)
        }
        .pickerStyle(.segmented)
    }
}
