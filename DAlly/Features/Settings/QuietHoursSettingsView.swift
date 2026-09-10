import SwiftUI
import SwiftData

struct QuietHoursSettingsView: View {
    @AppStorage(AppStorageKey.quietHoursEnabled) private var enabled = AppDefaults.quietHoursEnabled
    @AppStorage(AppStorageKey.quietHoursStartHour) private var startHour = AppDefaults.quietHoursStartHour
    @AppStorage(AppStorageKey.quietHoursStartMinute) private var startMinute = AppDefaults.quietHoursStartMinute
    @AppStorage(AppStorageKey.quietHoursEndHour) private var endHour = AppDefaults.quietHoursEndHour
    @AppStorage(AppStorageKey.quietHoursEndMinute) private var endMinute = AppDefaults.quietHoursEndMinute
    @Environment(\.modelContext) private var modelContext

    private var quiet: QuietHours {
        QuietHours(enabled: enabled, startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute)
    }

    var body: some View {
        Toggle("Quiet hours", isOn: $enabled)
        if quiet.isInvalidZeroSpan && enabled {
            Text(AppCopy.quietInvalid)
                .font(.footnote)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
        TimeOfDayPicker(title: "Starts", hour: $startHour, minute: $startMinute)
        TimeOfDayPicker(title: "Ends", hour: $endHour, minute: $endMinute)
        Text(AppCopy.quietHelper)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .onChange(of: enabled) { _, _ in reschedule() }
            .onChange(of: startHour) { _, _ in validateAndReschedule() }
            .onChange(of: startMinute) { _, _ in validateAndReschedule() }
            .onChange(of: endHour) { _, _ in validateAndReschedule() }
            .onChange(of: endMinute) { _, _ in validateAndReschedule() }
    }

    private func validateAndReschedule() {
        let q = QuietHours(
            enabled: enabled,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
        if q.isInvalidZeroSpan && enabled {
            enabled = false
        }
        reschedule()
    }

    private func reschedule() {
        NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
    }
}
