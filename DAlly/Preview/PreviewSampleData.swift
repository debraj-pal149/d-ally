import SwiftData
import Foundation

enum PreviewSampleData {
    @MainActor
    static func seedIfNeeded(into context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<DailyTask>())) ?? []
        guard existing.isEmpty else { return }
        _ = makeSampleTasks(context: context)
        try? context.save()
    }

    @MainActor
    static func container() -> ModelContainer {
        let schema = Schema([DailyTask.self, TaskDayLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        _ = makeSampleTasks(context: container.mainContext)
        try? container.mainContext.save()
        return container
    }

    @discardableResult
    @MainActor
    private static func makeSampleTasks(context: ModelContext) -> [DailyTask] {
        let today = Date().startOfLocalDay

        let pill = DailyTask(
            name: "Take morning pill",
            notes: "With water",
            scheduleKind: .fixedTime,
            hour: 8,
            minute: 0,
            colorHex: "#007AFF",
            markPattern: .solid
        )
        let smoke = DailyTask(
            name: "No cigarettes",
            scheduleKind: .flexibleUntil,
            hour: 16,
            minute: 0,
            windowEndHour: 22,
            windowEndMinute: 0,
            colorHex: "#FF3B30",
            markPattern: .solid
        )
        let gym = DailyTask(
            name: "Gym",
            scheduleKind: .flexibleUntil,
            hour: 17,
            minute: 0,
            windowEndHour: 21,
            windowEndMinute: 0,
            colorHex: "#34C759",
            markPattern: .solid,
            overdueReminderMode: .everyHourUntilDone
        )
        let meds = DailyTask(
            name: "Evening meds",
            scheduleKind: .fixedTime,
            hour: 21,
            minute: 0,
            colorHex: "#AF52DE",
            markPattern: .solid
        )
        let stretch = DailyTask(
            name: "Stretch 10 minutes",
            scheduleKind: .fixedTime,
            hour: 7,
            minute: 30,
            colorHex: "#FF9500",
            markPattern: .solid
        )
        let walk = DailyTask(
            name: "Walk outside",
            notes: "Around the block is fine",
            scheduleKind: .flexibleUntil,
            hour: 12,
            minute: 0,
            windowEndHour: 18,
            windowEndMinute: 0,
            colorHex: "#30B0C7",
            markPattern: .solid
        )
        let read = DailyTask(
            name: "Read before bed",
            scheduleKind: .flexibleUntil,
            hour: 21,
            minute: 30,
            windowEndHour: 23,
            windowEndMinute: 0,
            colorHex: "#5856D6",
            markPattern: .solid
        )
        [stretch, pill, walk, gym, smoke, meds, read].forEach { context.insert($0) }

        let yesterday = today.addingLocalDays(-1)
        let twoAgo = today.addingLocalDays(-2)
        context.insert(TaskDayLog(taskId: pill.id, dayKey: yesterday.localDayKey, status: .kept))
        context.insert(TaskDayLog(taskId: gym.id, dayKey: yesterday.localDayKey, status: .kept))
        context.insert(TaskDayLog(taskId: smoke.id, dayKey: twoAgo.localDayKey, status: .skipped))
        context.insert(TaskDayLog(taskId: stretch.id, dayKey: today.localDayKey, status: .kept))
        context.insert(TaskDayLog(taskId: pill.id, dayKey: today.localDayKey, status: .kept))
        context.insert(TaskDayLog(taskId: walk.id, dayKey: today.localDayKey, status: .kept))
        return [stretch, pill, walk, gym, smoke, meds, read]
    }
}
