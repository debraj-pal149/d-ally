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

final class RepeatCadenceTests: XCTestCase {
    func testEveryTwoDaysFromStart() {
        let start = Date().startOfLocalDay
        let task = DailyTask(
            name: "Run",
            colorHex: "#34C759",
            startDate: start,
            repeatKind: .everyNDays,
            repeatIntervalDays: 2
        )
        XCTAssertTrue(task.isActive(on: start))
        XCTAssertFalse(task.isActive(on: start.addingLocalDays(1)))
        XCTAssertTrue(task.isActive(on: start.addingLocalDays(2)))
        XCTAssertFalse(task.isActive(on: start.addingLocalDays(3)))
        XCTAssertTrue(task.isActive(on: start.addingLocalDays(4)))
    }

    func testWeeklyOnlySelectedWeekday() {
        let cal = Calendar.current
        // 2026-09-07 is Monday
        let monday = cal.date(from: DateComponents(calendar: cal, year: 2026, month: 9, day: 7))!.startOfLocalDay
        XCTAssertEqual(cal.component(.weekday, from: monday), 2)
        let task = DailyTask(
            name: "Gym",
            colorHex: "#007AFF",
            startDate: monday.addingLocalDays(-7),
            repeatKind: .weekly,
            weeklyWeekdaysMask: WeeklyWeekdays.mask(for: [2]) // Monday
        )
        XCTAssertTrue(task.isActive(on: monday))
        XCTAssertFalse(task.isActive(on: monday.addingLocalDays(1))) // Tue
        XCTAssertTrue(task.isActive(on: monday.addingLocalDays(7)))
    }

    func testDailyStillEveryDay() {
        let start = Date().startOfLocalDay
        let task = DailyTask(name: "Pill", colorHex: "#FF3B30", startDate: start)
        XCTAssertTrue(task.isActive(on: start))
        XCTAssertTrue(task.isActive(on: start.addingLocalDays(1)))
        XCTAssertFalse(task.isActive(on: start.addingLocalDays(-1)))
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
    @MainActor
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

    @MainActor
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

final class SyncMergeTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    func testRemoteNewerWins() {
        let decision = SyncMerge.decide(localUpdatedAt: base, localPendingAt: nil, remoteUpdatedAt: base.addingTimeInterval(5))
        XCTAssertEqual(decision, .applyRemote)
    }

    func testLocalNewerKept() {
        let decision = SyncMerge.decide(localUpdatedAt: base.addingTimeInterval(5), localPendingAt: nil, remoteUpdatedAt: base)
        XCTAssertEqual(decision, .keepLocal)
    }

    func testTieKeepsLocal() {
        XCTAssertEqual(SyncMerge.decide(localUpdatedAt: base, localPendingAt: nil, remoteUpdatedAt: base), .keepLocal)
    }

    func testPendingLocalChangeBlocksOlderRemote() {
        let decision = SyncMerge.decide(
            localUpdatedAt: base.addingTimeInterval(-100),
            localPendingAt: base.addingTimeInterval(10),
            remoteUpdatedAt: base
        )
        XCTAssertEqual(decision, .keepLocal)
    }

    func testNothingLocalTakesRemote() {
        XCTAssertEqual(SyncMerge.decide(localUpdatedAt: nil, localPendingAt: nil, remoteUpdatedAt: base), .applyRemote)
    }

    func testPushWhenRemoteMissingOrOlder() {
        XCTAssertTrue(SyncMerge.shouldPush(localChangedAt: base, remoteUpdatedAt: nil))
        XCTAssertTrue(SyncMerge.shouldPush(localChangedAt: base, remoteUpdatedAt: base.addingTimeInterval(-1)))
        XCTAssertTrue(SyncMerge.shouldPush(localChangedAt: base, remoteUpdatedAt: base))
        XCTAssertFalse(SyncMerge.shouldPush(localChangedAt: base, remoteUpdatedAt: base.addingTimeInterval(1)))
    }
}

final class CloudCodecTests: XCTestCase {
    func testHabitRoundTrip() {
        let start = Date().startOfLocalDay.addingLocalDays(-12)
        let task = DailyTask(
            name: "Gym",
            notes: "Legs",
            scheduleKind: .flexibleUntil,
            hour: 18,
            minute: 30,
            windowEndHour: 21,
            windowEndMinute: 0,
            priority: .high,
            colorHex: "#34C759",
            startDate: start,
            endDate: start.addingLocalDays(40),
            repeatKind: .weekly,
            weeklyWeekdaysMask: 0b0101010
        )
        let data = CloudCodec.habit(from: task)
        let cloud = CloudCodec.decodeHabit(data)
        XCTAssertNotNil(cloud)
        let copy = CloudCodec.makeTask(from: cloud!)
        XCTAssertEqual(copy.id, task.id)
        XCTAssertEqual(copy.name, "Gym")
        XCTAssertEqual(copy.notes, "Legs")
        XCTAssertEqual(copy.schedule, .flexibleUntil)
        XCTAssertEqual(copy.hour, 18)
        XCTAssertEqual(copy.windowEndHour, 21)
        XCTAssertEqual(copy.priorityLevel, .high)
        XCTAssertEqual(copy.startDate, start)
        XCTAssertEqual(copy.endDate, start.addingLocalDays(40))
        XCTAssertEqual(copy.repeatCadence, .weekly)
        XCTAssertEqual(copy.weeklyWeekdaysMask, 0b0101010)
        XCTAssertEqual(copy.updatedAt, task.updatedAt)
        XCTAssertNil(cloud?.deletedAt)
    }

    func testHabitSoftDeleteRoundTrip() {
        let task = DailyTask(name: "Pill", colorHex: "#FF3B30")
        let when = Date()
        task.deletedAt = when
        task.isStopped = true
        task.notificationsEnabled = false
        let data = CloudCodec.habit(from: task)
        let cloud = CloudCodec.decodeHabit(data)
        XCTAssertEqual(cloud?.name, "Pill")
        XCTAssertEqual(cloud?.deletedAt, when)
        let copy = CloudCodec.makeTask(from: cloud!)
        XCTAssertEqual(copy.name, "Pill")
        XCTAssertEqual(copy.deletedAt, when)
        XCTAssertTrue(copy.isStopped)
        XCTAssertFalse(copy.isLive)
    }

    func testHabitTombstoneDecodes() {
        let id = UUID()
        let when = Date()
        let cloud = CloudCodec.decodeHabit(CloudCodec.habitTombstone(id: id, deletedAt: when))
        XCTAssertEqual(cloud?.id, id)
        XCTAssertEqual(cloud?.deletedAt, when)
        XCTAssertEqual(cloud?.updatedAt, when)
    }

    func testLogRoundTripAndKey() {
        let taskId = UUID()
        let log = TaskDayLog(taskId: taskId, dayKey: "2026-09-27", status: .skipped)
        let cloud = CloudCodec.decodeLog(CloudCodec.log(from: log))
        XCTAssertEqual(cloud?.taskId, taskId)
        XCTAssertEqual(cloud?.dayKey, "2026-09-27")
        XCTAssertEqual(cloud?.status, DayLogStatus.skipped.rawValue)
        XCTAssertEqual(cloud?.updatedAt, log.updatedAt)

        let key = SyncKeys.log(taskId: taskId, dayKey: "2026-09-27")
        let parts = SyncKeys.splitLog(key)
        XCTAssertEqual(parts?.taskId, taskId)
        XCTAssertEqual(parts?.dayKey, "2026-09-27")
    }

    func testBookmarkRoundTrip() {
        let bookmark = DayBookmark(title: "Doctor", notes: "Annual", dayKey: "2026-10-02")
        let cloud = CloudCodec.decodeBookmark(CloudCodec.bookmark(from: bookmark))
        XCTAssertEqual(cloud?.id, bookmark.id)
        XCTAssertEqual(cloud?.title, "Doctor")
        XCTAssertEqual(cloud?.notes, "Annual")
        XCTAssertEqual(cloud?.dayKey, "2026-10-02")
        XCTAssertNil(cloud?.deletedAt)
        let copy = CloudCodec.makeBookmark(from: cloud!)
        XCTAssertEqual(copy.title, "Doctor")
        XCTAssertEqual(copy.dayKey, "2026-10-02")
        XCTAssertTrue(copy.isLive)
    }

    func testBookmarkSoftDeleteRoundTrip() {
        let bookmark = DayBookmark(title: "Doctor", dayKey: "2026-10-02")
        let when = Date()
        bookmark.deletedAt = when
        let cloud = CloudCodec.decodeBookmark(CloudCodec.bookmark(from: bookmark))
        XCTAssertEqual(cloud?.deletedAt, when)
        let copy = CloudCodec.makeBookmark(from: cloud!)
        XCTAssertFalse(copy.isLive)
    }

    func testHabitColorRejectsBookmarkBlackAndWhite() {
        XCTAssertTrue(TaskColorPalette.isReservedForBookmarks("#000000"))
        XCTAssertTrue(TaskColorPalette.isReservedForBookmarks("#FFFFFF"))
        XCTAssertTrue(TaskColorPalette.isReservedForBookmarks("#0A0A0A"))
        XCTAssertTrue(TaskColorPalette.isReservedForBookmarks("#FAFAFA"))
        XCTAssertFalse(TaskColorPalette.isReservedForBookmarks("#1C3D5A"))
        XCTAssertFalse(TaskColorPalette.isReservedForBookmarks("#007AFF"))
        for swatch in TaskColorPalette.forHabits {
            XCTAssertFalse(TaskColorPalette.isReservedForBookmarks(swatch.hex), swatch.name)
        }
        XCTAssertEqual(TaskColorPalette.habitSafeHex("#000000"), TaskColorPalette.forHabits[0].hex)
        XCTAssertEqual(TaskColorPalette.habitSafeHex("#FFFFFF"), TaskColorPalette.forHabits[0].hex)
    }
}

final class DayBookmarkTests: XCTestCase {
    func testLiveFiltersToOneDay() {
        let a = DayBookmark(title: "A", dayKey: "2026-10-02")
        let b = DayBookmark(title: "B", dayKey: "2026-10-03")
        let deleted = DayBookmark(title: "Gone", dayKey: "2026-10-02", deletedAt: Date())
        let day = Date.date(fromDayKey: "2026-10-02")!
        let live = DayBookmark.live(on: day, in: [a, b, deleted])
        XCTAssertEqual(live.map(\.title), ["A"])
    }
}

@MainActor
final class SyncRecorderTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([DailyTask.self, TaskDayLog.self, SyncOutbox.self, DayBookmark.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    func testMarkKeptQueuesOneChangePerDay() throws {
        let context = try makeContext()
        let task = DailyTask(name: "Pill", colorHex: "#007AFF")
        context.insert(task)
        try context.save()

        let day = Date().startOfLocalDay
        DayLogService.markKept(taskId: task.id, day: day, in: context)
        DayLogService.markSkipped(taskId: task.id, day: day, in: context)

        let pending = SyncRecorder.pending(in: context)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.recordKind, .log)
        XCTAssertFalse(pending.first?.isTombstone ?? true)
    }

    func testClearLogQueuesTombstone() throws {
        let context = try makeContext()
        let task = DailyTask(name: "Pill", colorHex: "#007AFF")
        context.insert(task)
        try context.save()
        let day = Date().startOfLocalDay
        DayLogService.markKept(taskId: task.id, day: day, in: context)
        DayLogService.clearLog(taskId: task.id, day: day, in: context)

        let pending = SyncRecorder.pending(in: context)
        XCTAssertEqual(pending.count, 1)
        XCTAssertTrue(pending.first?.isTombstone ?? false)
        XCTAssertEqual((try? context.fetch(FetchDescriptor<TaskDayLog>()))?.count, 0)
    }

    func testEnqueueAllIsIdempotent() throws {
        let context = try makeContext()
        let a = DailyTask(name: "A", colorHex: "#007AFF")
        let b = DailyTask(name: "B", colorHex: "#34C759")
        context.insert(a)
        context.insert(b)
        context.insert(TaskDayLog(taskId: a.id, dayKey: "2026-09-20", status: .kept))
        context.insert(DayBookmark(title: "Doctor", dayKey: "2026-10-02"))
        try context.save()

        SyncRecorder.enqueueAll(in: context)
        SyncRecorder.enqueueAll(in: context)
        XCTAssertEqual(SyncRecorder.pending(in: context).count, 4)
    }

    func testBookmarkChangedQueuesOutbox() throws {
        let context = try makeContext()
        let bookmark = DayBookmark(title: "Doctor", dayKey: "2026-10-02")
        context.insert(bookmark)
        try context.save()
        SyncRecorder.bookmarkChanged(bookmark.id, in: context)
        let pending = SyncRecorder.pending(in: context)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.recordKind, .bookmark)
        XCTAssertFalse(pending.first?.isTombstone ?? true)
    }
}

final class MonthConsistencyTests: XCTestCase {
    func testCountsScheduledDaysThroughYesterdayAndTodayOnlyWhenResolved() {
        let today = Date().startOfLocalDay
        let calendar = Calendar.current
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        guard today > monthStart.addingLocalDays(2) else { return }

        let task = DailyTask(name: "Pill", colorHex: "#007AFF", startDate: monthStart)
        var logs: [TaskDayLog] = []
        logs.append(TaskDayLog(taskId: task.id, dayKey: monthStart.localDayKey, status: .kept))
        logs.append(TaskDayLog(taskId: task.id, dayKey: monthStart.addingLocalDays(1).localDayKey, status: .skipped))

        let dayCount = calendar.dateComponents([.day], from: monthStart, to: today).day ?? 0
        let open = MonthConsistency.count(task: task, logs: logs, viewing: today, now: today.addingTimeInterval(3600))
        XCTAssertEqual(open.scheduled, dayCount)
        XCTAssertEqual(open.kept, 1)

        logs.append(TaskDayLog(taskId: task.id, dayKey: today.localDayKey, status: .kept))
        let done = MonthConsistency.count(task: task, logs: logs, viewing: today, now: today.addingTimeInterval(3600))
        XCTAssertEqual(done.scheduled, dayCount + 1)
        XCTAssertEqual(done.kept, 2)
    }
}

final class SoftDeleteHistoryTests: XCTestCase {
    func testDeletedHabitAppearsInEndedOnlyThroughDeletedDay() {
        let start = Date().startOfLocalDay.addingLocalDays(-5)
        let deletedDay = start.addingLocalDays(2)
        let task = DailyTask(name: "Pill", colorHex: "#FF3B30", startDate: start)
        task.endDate = deletedDay
        task.deletedAt = deletedDay.addingTimeInterval(15 * 3600) // afternoon of deleted day
        task.isStopped = true

        XCTAssertFalse(task.isActive(on: deletedDay))
        XCTAssertTrue(task.belongsInEndedHistory(on: deletedDay))
        XCTAssertTrue(task.belongsInEndedHistory(on: start))
        XCTAssertFalse(task.belongsInEndedHistory(on: start.addingLocalDays(-1)))
        XCTAssertFalse(task.belongsInEndedHistory(on: deletedDay.addingLocalDays(1)))

        let endedOnDeleteDay = TaskOccurrenceService.endedHistory(for: deletedDay, allTasks: [task])
        XCTAssertEqual(endedOnDeleteDay.map(\.id), [task.id])

        let endedAfter = TaskOccurrenceService.endedHistory(
            for: deletedDay.addingLocalDays(1),
            allTasks: [task]
        )
        XCTAssertTrue(endedAfter.isEmpty)
    }

    func testOldOneDayHabitDeletedLaterDoesNotAppearOnToday() {
        let start = Date().startOfLocalDay.addingLocalDays(-90)
        let task = DailyTask(
            name: "One day",
            colorHex: "#007AFF",
            startDate: start,
            endDate: start
        )
        // Soft-deleted today must not extend history past the original end.
        task.deletedAt = Date()
        task.isStopped = true

        let today = Date().startOfLocalDay
        XCTAssertFalse(task.belongsInEndedHistory(on: today))
        XCTAssertTrue(task.belongsInEndedHistory(on: start))
        XCTAssertTrue(TaskOccurrenceService.endedHistory(for: today, allTasks: [task]).isEmpty)
    }

    func testStoppedWithoutEndDateExcludedUntilRepaired() {
        let start = Date().startOfLocalDay.addingLocalDays(-3)
        let today = Date().startOfLocalDay
        let task = DailyTask(name: "Gym", colorHex: "#34C759", startDate: start)
        task.isStopped = true
        // No endDate: must not haunt every day.
        XCTAssertNil(task.historyEndDay)
        XCTAssertFalse(task.belongsInEndedHistory(on: today))
        XCTAssertTrue(TaskOccurrenceService.endedHistory(for: today, allTasks: [task]).isEmpty)

        task.endDate = today
        XCTAssertTrue(task.belongsInEndedHistory(on: today))
        XCTAssertFalse(task.belongsInEndedHistory(on: today.addingLocalDays(1)))
    }
}
