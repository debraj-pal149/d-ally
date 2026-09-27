import AppIntents

struct DAllyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: MarkKeptIntent(),
            phrases: [
                "Mark \(\.$habit) kept in \(.applicationName)",
                "Mark \(\.$habit) done in \(.applicationName)",
                "I kept \(\.$habit) in \(.applicationName)",
            ],
            shortTitle: "Mark kept",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: SkipTodayIntent(),
            phrases: [
                "Skip \(\.$habit) in \(.applicationName)",
                "Skip \(\.$habit) today in \(.applicationName)",
            ],
            shortTitle: "Skip today",
            systemImageName: "arrow.right.circle"
        )
    }
}
