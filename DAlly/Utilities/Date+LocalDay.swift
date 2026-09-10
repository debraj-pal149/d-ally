import Foundation

extension Date {
    var startOfLocalDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var localDayKey: String {
        Date.dayKeyFormatter.string(from: self)
    }

    static func date(fromDayKey key: String) -> Date? {
        Date.dayKeyFormatter.date(from: key)
    }

    static func isSameLocalDay(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, inSameDayAs: b)
    }

    func addingLocalDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: startOfLocalDay) ?? self
    }

    var endOfLocalDay: Date {
        let start = startOfLocalDay
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

enum TimeDisplay {
    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func clock(hour: Int, minute: Int, on day: Date = Date()) -> String {
        let d = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day.startOfLocalDay) ?? day
        return clock(d)
    }

    static func weekdayMonthDay(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
}
