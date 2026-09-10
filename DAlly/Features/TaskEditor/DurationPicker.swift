import SwiftUI

struct DurationPicker: View {
    @Binding var untilStopped: Bool
    @Binding var endDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Duration", selection: $untilStopped) {
                Text("Until I stop").tag(true)
                Text("Until a date").tag(false)
            }
            .pickerStyle(.segmented)
            if !untilStopped {
                DatePicker("Ends", selection: $endDate, in: Date().startOfLocalDay..., displayedComponents: .date)
            }
        }
    }
}
