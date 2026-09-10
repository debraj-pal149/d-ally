import Foundation

struct QuietHours: Equatable {
    var enabled: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int

    static var appDefaults: QuietHours {
        QuietHours(
            enabled: AppDefaults.quietHoursEnabled,
            startHour: AppDefaults.quietHoursStartHour,
            startMinute: AppDefaults.quietHoursStartMinute,
            endHour: AppDefaults.quietHoursEndHour,
            endMinute: AppDefaults.quietHoursEndMinute
        )
    }

    var startMinutes: Int { startHour * 60 + startMinute }
    var endMinutes: Int { endHour * 60 + endMinute }

    var isInvalidZeroSpan: Bool { startMinutes == endMinutes }

    var isEffectivelyOn: Bool { enabled && !isInvalidZeroSpan }

    func isInQuietHours(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEffectivelyOn else { return false }
        let mins = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if startMinutes > endMinutes {
            return mins >= startMinutes || mins < endMinutes
        }
        return mins >= startMinutes && mins < endMinutes
    }

    func nextQuietEnd(after date: Date, calendar: Calendar = .current) -> Date {
        guard isEffectivelyOn else { return date }
        if !isInQuietHours(at: date, calendar: calendar) {
            return date
        }
        let startOfDay = calendar.startOfDay(for: date)
        if startMinutes > endMinutes {
            // Quiet spans midnight: ends today at endHour if we're after midnight, else tomorrow
            let mins = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
            if mins >= startMinutes {
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
                return calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: tomorrow) ?? date
            }
            return calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: startOfDay) ?? date
        }
        return calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: startOfDay) ?? date
    }
}
