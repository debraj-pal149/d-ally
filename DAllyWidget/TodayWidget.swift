import SwiftData
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    var date: Date
    var snapshot: TodaySnapshot
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let entry = load()
        completion(Timeline(entries: [entry], policy: .after(entry.snapshot.nextRefresh)))
    }

    private func load() -> TodayEntry {
        let storeReady = Persistence.storeURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        guard storeReady else {
            return TodayEntry(
                date: Date(),
                snapshot: TodaySnapshot(
                    dayKey: Date().localDayKey,
                    habits: [],
                    nextRefresh: Date().addingTimeInterval(30 * 60),
                    storeReady: false
                )
            )
        }
        let context = ModelContext(Persistence.shared)
        let tasks = (try? context.fetch(FetchDescriptor<DailyTask>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<TaskDayLog>())) ?? []
        return TodayEntry(date: Date(), snapshot: TodaySnapshotBuilder.make(tasks: tasks, logs: logs))
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayHabits", provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("d·ally")
        .description("Today’s open and kept habits.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

struct TodayWidgetView: View {
    var entry: TodayEntry
    @Environment(\.widgetFamily) private var family

    private var dayURL: URL? {
        URL(string: "dally://day?date=\(entry.snapshot.dayKey)")
    }

    var body: some View {
        content
            .widgetURL(dayURL)
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryInline, .accessoryCircular, .accessoryRectangular:
                    AccessoryWidgetBackground()
                default:
                    Color(uiColor: .secondarySystemGroupedBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text(entry.snapshot.headline)
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.snapshot.habits.isEmpty ? "—" : "\(entry.snapshot.openCount)")
                    .font(.headline)
                Text(entry.snapshot.habits.isEmpty ? "none" : "open")
                    .font(.caption2)
            }
        case .accessoryRectangular:
            habitList(limit: 2)
        case .systemMedium:
            VStack(alignment: .leading, spacing: 8) {
                header
                habitList(limit: 4)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                Text("d·ally")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(entry.snapshot.headline)
                    .font(.title2.weight(.semibold))
                    .minimumScaleFactor(0.7)
                if !entry.snapshot.habits.isEmpty {
                    Text("\(entry.snapshot.keptCount) kept")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack {
            Text("d·ally")
                .font(.headline)
            Spacer()
            Text(entry.snapshot.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func habitList(limit: Int) -> some View {
        let shown = Array(entry.snapshot.habits.prefix(limit))
        let extra = entry.snapshot.habits.count - shown.count
        return VStack(alignment: .leading, spacing: 6) {
            if shown.isEmpty {
                Text(entry.snapshot.storeReady ? "Nothing today" : "Open d·ally")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(shown) { habit in
                    habitRow(habit)
                }
                if extra > 0 {
                    Text("and \(extra) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func habitRow(_ habit: WidgetHabit) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: habit.colorHex))
                .frame(width: 8, height: 8)
            Text(habit.name)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button(intent: MarkKeptIntent(habit: HabitEntity(id: habit.id, name: habit.name))) {
                Image(systemName: habit.status == .kept ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark \(habit.name) kept")
            Button(intent: SkipTodayIntent(habit: HabitEntity(id: habit.id, name: habit.name))) {
                Image(systemName: habit.status == .skipped ? "arrow.right.circle.fill" : "arrow.right.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip \(habit.name) today")
        }
    }
}
