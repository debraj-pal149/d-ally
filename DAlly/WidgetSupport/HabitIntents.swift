import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct HabitEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitEntity] {
        try await MainActor.run {
            let context = Persistence.shared.mainContext
            let tasks = try context.fetch(FetchDescriptor<DailyTask>())
            return tasks.filter { identifiers.contains($0.id) }.map { HabitEntity(id: $0.id, name: $0.name) }
        }
    }

    func suggestedEntities() async throws -> [HabitEntity] {
        try await MainActor.run {
            let context = Persistence.shared.mainContext
            let tasks = try context.fetch(FetchDescriptor<DailyTask>())
            return TaskOccurrenceService.tasks(for: Date().startOfLocalDay, allTasks: tasks)
                .map { HabitEntity(id: $0.id, name: $0.name) }
        }
    }
}

enum HabitLogError: Error, CustomLocalizedStringResourceConvertible {
    case missingHabit

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .missingHabit: "That habit is gone."
        }
    }
}

enum HabitLogWriter {
    @MainActor
    static func apply(taskId: UUID, status: DayLogStatus, context: ModelContext) throws -> DailyTask {
        let tasks = try context.fetch(FetchDescriptor<DailyTask>())
        guard let task = tasks.first(where: { $0.id == taskId }) else { throw HabitLogError.missingHabit }
        switch status {
        case .kept:
            DayLogService.markKept(taskId: task.id, day: Date().startOfLocalDay, in: context)
        case .skipped:
            DayLogService.markSkipped(taskId: task.id, day: Date().startOfLocalDay, in: context)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return task
    }
}

struct MarkKeptIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark kept"
    static var description = IntentDescription("Marks a d·ally habit as kept for today.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Habit")
    var habit: HabitEntity

    init() {}

    init(habit: HabitEntity) {
        self.habit = habit
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let task = try HabitLogWriter.apply(taskId: habit.id, status: .kept, context: Persistence.shared.mainContext)
        return .result(dialog: "\(task.name) kept.")
    }
}

struct SkipTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Skip today"
    static var description = IntentDescription("Skips a d·ally habit for today.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Habit")
    var habit: HabitEntity

    init() {}

    init(habit: HabitEntity) {
        self.habit = habit
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let task = try HabitLogWriter.apply(taskId: habit.id, status: .skipped, context: Persistence.shared.mainContext)
        return .result(dialog: "\(task.name) skipped today.")
    }
}
