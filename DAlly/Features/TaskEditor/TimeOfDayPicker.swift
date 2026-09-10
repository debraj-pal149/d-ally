import SwiftUI

struct TimeOfDayPicker: View {
    var title: String
    @Binding var hour: Int
    @Binding var minute: Int

    private var date: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(on: Date(), hour: hour, minute: minute)
            },
            set: { new in
                hour = Calendar.current.component(.hour, from: new)
                minute = Calendar.current.component(.minute, from: new)
            }
        )
    }

    var body: some View {
        DatePicker(title, selection: date, displayedComponents: .hourAndMinute)
    }
}
