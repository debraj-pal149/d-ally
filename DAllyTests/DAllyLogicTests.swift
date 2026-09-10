import XCTest
import SwiftData
@testable import DAlly

final class DateLocalDayTests: XCTestCase {
    func testDayKeyRoundTrip() {
        let day = Date().startOfLocalDay
        let key = day.localDayKey
        XCTAssertEqual(key.count, 10)
        let back = Date.date(fromDayKey: key)
        XCTAssertNotNil(back)
        XCTAssertTrue(Date.isSameLocalDay(day, back!))
    }
}

final class QuietHoursTests: XCTestCase {
    func testOvernightWindow() {
        let q = QuietHours(enabled: true, startHour: 22, startMinute: 0, endHour: 7, endMinute: 0)
        let cal = Calendar.current
        let day = Date().startOfLocalDay
        let at23 = cal.date(bySettingHour: 23, minute: 0, second: 0, of: day)!
        let at3 = cal.date(bySettingHour: 3, minute: 0, second: 0, of: day)!
        let at8 = cal.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        XCTAssertTrue(q.isInQuietHours(at: at23, calendar: cal))
        XCTAssertTrue(q.isInQuietHours(at: at3, calendar: cal))
        XCTAssertFalse(q.isInQuietHours(at: at8, calendar: cal))
        let end = q.nextQuietEnd(after: at23, calendar: cal)
        XCTAssertEqual(cal.component(.hour, from: end), 7)
    }

    func testSameNightSlice() {
        let q = QuietHours(enabled: true, startHour: 1, startMinute: 0, endHour: 5, endMinute: 0)
        let cal = Calendar.current
        let day = Date().startOfLocalDay
        let at2 = cal.date(bySettingHour: 2, minute: 0, second: 0, of: day)!
        let at6 = cal.date(bySettingHour: 6, minute: 0, second: 0, of: day)!
        XCTAssertTrue(q.isInQuietHours(at: at2, calendar: cal))
        XCTAssertFalse(q.isInQuietHours(at: at6, calendar: cal))
    }

    func testZeroSpanOff() {
        let q = QuietHours(enabled: true, startHour: 22, startMinute: 0, endHour: 22, endMinute: 0)
        XCTAssertTrue(q.isInvalidZeroSpan)
        XCTAssertFalse(q.isEffectivelyOn)
        XCTAssertFalse(q.isInQuietHours(at: Date()))
    }
}

final class DaySectioningTests: XCTestCase {
    func testNextHourIncludesDueWithinHour() {
        let now = Date()
        let due = now.addingTimeInterval(30 * 60)
        XCTAssertTrue(DaySectioningService.isNextHour(due: due, nudge: due, now: now))
        let later = now.addingTimeInterval(2 * 3600)
        XCTAssertFalse(DaySectioningService.isNextHour(due: later, nudge: later, now: now))
    }

    func testNextHourIncludesUpcomingNudge() {
        let now = Date()
        let nudge = now.addingTimeInterval(20 * 60)
        let due = now.addingTimeInterval(5 * 3600)
        XCTAssertTrue(DaySectioningService.isNextHour(due: due, nudge: nudge, now: now))
    }
}

final class FlexibleValidationTests: XCTestCase {
    func testNudgeMustBeBeforeOrEqualCompleteBy() {
        XCTAssertTrue(DailyTask.flexibleWindowValid(nudgeHour: 18, nudgeMinute: 0, endHour: 22, endMinute: 0))
        XCTAssertTrue(DailyTask.flexibleWindowValid(nudgeHour: 22, nudgeMinute: 0, endHour: 22, endMinute: 0))
        XCTAssertFalse(DailyTask.flexibleWindowValid(nudgeHour: 23, nudgeMinute: 0, endHour: 22, endMinute: 0))
    }
}

final class NotificationIDTests: XCTestCase {
    func testIDsContainTaskAndDay() {
        let id = UUID()
        let key = "2026-09-03"
        let ontime = NotificationIDs.ontime(taskId: id, dayKey: key)
        XCTAssertTrue(NotificationIDs.matches(taskId: id, dayKey: key, identifier: ontime))
        let parsed = NotificationIDs.parseTaskAndDay(from: ontime)
        XCTAssertEqual(parsed?.0, id)
        XCTAssertEqual(parsed?.1, key)
    }
}

final class DueDateConstructionTests: XCTestCase {
    func testEveningDueIsNotPastInMorning() {
        let cal = Calendar.current
        let day = Date().startOfLocalDay
        let morning = cal.date(from: {
            var c = cal.dateComponents([.year, .month, .day], from: day)
            c.hour = 10; c.minute = 27; c.second = 0
            return c
        }())!
        let due = cal.date(on: day, hour: 21, minute: 0)
        XCTAssertEqual(cal.component(.hour, from: due), 21)
        XCTAssertTrue(due > morning)
        XCTAssertFalse(DaySectioningService.isNextHour(due: due, nudge: due, now: morning))
        let task = DailyTask(name: "Evening", scheduleKind: .fixedTime, hour: 21, minute: 0, colorHex: "#FF4D6D")
        let sections = DaySectioningService.sections(day: day, tasks: [task], logs: [], now: morning)
        XCTAssertEqual(sections.map(\.id), [.later])
    }
}

final class WeekReviewSchedulingTests: XCTestCase {
    func testNextSundayNoonIsSundayAtTwelve() {
        let cal = Calendar.current
        // A known Wednesday
        var comps = DateComponents(year: 2026, month: 9, day: 9, hour: 10, minute: 0) // Tue Sep 9 2026? check
        // Use a fixed Wednesday: 2026-09-09 was a Wednesday
        comps = DateComponents(calendar: cal, year: 2026, month: 9, day: 9, hour: 15, minute: 0)
        let wednesday = cal.date(from: comps)!
        XCTAssertEqual(cal.component(.weekday, from: wednesday), 4) // Wednesday

        let next = NotificationSchedulingService.nextSundayNoon(after: wednesday)
        XCTAssertNotNil(next)
        XCTAssertEqual(cal.component(.weekday, from: next!), 1)
        XCTAssertEqual(cal.component(.hour, from: next!), 12)
        XCTAssertEqual(cal.component(.minute, from: next!), 0)
        XCTAssertTrue(next! > wednesday)
    }

    func testSundayBeforeNoonUsesToday() {
        let cal = Calendar.current
        // 2026-09-06 is Sunday
        let comps = DateComponents(calendar: cal, year: 2026, month: 9, day: 6, hour: 9, minute: 0)
        let sundayMorning = cal.date(from: comps)!
        XCTAssertEqual(cal.component(.weekday, from: sundayMorning), 1)

        let next = NotificationSchedulingService.nextSundayNoon(after: sundayMorning)
        XCTAssertNotNil(next)
        XCTAssertTrue(Calendar.current.isDate(next!, inSameDayAs: sundayMorning))
        XCTAssertEqual(cal.component(.hour, from: next!), 12)
    }
}

final class DayLogIndependenceTests: XCTestCase {
    @MainActor
    func testMarkingOneDayDoesNotAffectAnother() throws {
        let schema = Schema([DailyTask.self, TaskDayLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = ModelContext(container)

        let task = DailyTask(name: "Pill", colorHex: "#007AFF")
        context.insert(task)
        try context.save()

        let today = Date().startOfLocalDay
        let yesterday = today.addingLocalDays(-1)

        DayLogService.markKept(taskId: task.id, day: yesterday, in: context)

        let logs = try context.fetch(FetchDescriptor<TaskDayLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].dayKey, yesterday.localDayKey)
        XCTAssertEqual(DayLogService.status(taskId: task.id, day: yesterday, logs: logs), .kept)
        XCTAssertNil(DayLogService.status(taskId: task.id, day: today, logs: logs))

        DayLogService.markKept(taskId: task.id, day: today, in: context)
        let logs2 = try context.fetch(FetchDescriptor<TaskDayLog>())
        XCTAssertEqual(logs2.count, 2)
        XCTAssertEqual(DayLogService.status(taskId: task.id, day: yesterday, logs: logs2), .kept)
        XCTAssertEqual(DayLogService.status(taskId: task.id, day: today, logs: logs2), .kept)
    }
}

final class SchedulingLogicTests: XCTestCase {
    func testNoHourliesInsideQuietHours() {
        let task = DailyTask(
            name: "Gym",
            scheduleKind: .fixedTime,
            hour: 21,
            minute: 0,
            colorHex: "#FF7A59",
            overdueReminderMode: .everyHourUntilDone
        )
        let day = Date().startOfLocalDay
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = 10
        comps.minute = 0
        let now = Calendar.current.date(from: comps)!
        let items = NotificationSchedulingService.shared.notifications(for: task, day: day, dayKey: day.localDayKey, now: now)
        let quiet = QuietHours.appDefaults
        for item in items where item.kind == "overdueHourly" {
            XCTAssertFalse(quiet.isInQuietHours(at: item.fire), "hourly at \(item.fire) should not be in quiet hours")
        }
        XCTAssertTrue(items.contains { $0.kind == "ontime" })
    }

    func testOverdueOnceDefersOutOfQuietHoursEvenIfCandidatePassed() {
        // Force quiet hours window for the test via UserDefaults used by QuietHoursService
        let d = UserDefaults.standard
        d.set(true, forKey: AppStorageKey.quietHoursEnabled)
        d.set(22, forKey: AppStorageKey.quietHoursStartHour)
        d.set(0, forKey: AppStorageKey.quietHoursStartMinute)
        d.set(7, forKey: AppStorageKey.quietHoursEndHour)
        d.set(0, forKey: AppStorageKey.quietHoursEndMinute)

        let task = DailyTask(
            name: "Meds",
            scheduleKind: .fixedTime,
            hour: 22,
            minute: 0,
            colorHex: "#FF4D6D",
            overdueReminderMode: .onceAfter10Minutes
        )
        let day = Date().startOfLocalDay
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.hour = 23
        comps.minute = 30
        let now = Calendar.current.date(from: comps)!
        let items = NotificationSchedulingService.shared.notifications(for: task, day: day, dayKey: day.localDayKey, now: now)
        let overdue = items.first { $0.kind == "overdueOnce" }
        XCTAssertNotNil(overdue)
        XCTAssertEqual(Calendar.current.component(.hour, from: overdue!.fire), 7)
        XCTAssertFalse(QuietHoursService.isInQuietHours(at: overdue!.fire))
    }
}
