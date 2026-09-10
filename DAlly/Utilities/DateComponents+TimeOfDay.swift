import Foundation

extension DateComponents {
    static func timeOfDay(hour: Int, minute: Int) -> DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    var minutesFromMidnight: Int {
        (hour ?? 0) * 60 + (minute ?? 0)
    }
}

extension Calendar {
    func date(on day: Date, hour: Int, minute: Int) -> Date {
        var comps = dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return date(from: comps) ?? startOfDay(for: day)
    }
}
