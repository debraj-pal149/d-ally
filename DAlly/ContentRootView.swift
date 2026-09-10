import SwiftUI
import SwiftData

struct ContentRootView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKey.appearanceMode) private var appearanceMode = AppDefaults.appearanceMode

    var body: some View {
        @Bindable var router = router
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.preferredColorScheme)
        .sheet(isPresented: $router.showTaskEditor) {
            TaskEditorView(taskId: router.editingTaskId)
        }
        .sheet(item: $router.taskActionPrompt) { prompt in
            CompletionPromptSheet(taskId: prompt.taskId, day: prompt.day)
        }
        .sheet(isPresented: $router.showNotificationPriming) {
            NotificationPrimingView()
        }
        .onOpenURL { router.apply(url: $0) }
        .onReceive(NotificationCenter.default.publisher(for: .dallyOpenURL)) { note in
            if let url = note.object as? URL {
                router.apply(url: url)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
            }
            // Do not auto-jump selectedDay back to today on foreground/sheet cycles —
            // that broke completing tasks on previous days. Use “Back to today” instead.
        }
        .onAppear {
            NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
            if UserDefaults.standard.bool(forKey: "seedPreviewData") {
                PreviewSampleData.seedIfNeeded(into: modelContext)
                UserDefaults.standard.set(false, forKey: "seedPreviewData")
            }
            if let tab = UserDefaults.standard.string(forKey: "bootTab") {
                switch tab {
                case "calendar": router.selectedTab = .calendar
                case "settings": router.selectedTab = .settings
                case "editor":
                    router.selectedTab = .day
                    router.openEditor(taskId: nil)
                default: router.selectedTab = .day
                }
                UserDefaults.standard.removeObject(forKey: "bootTab")
            }
        }
        .onLocalDayChange {
            if Date.isSameLocalDay(router.selectedDay, Date().addingLocalDays(-1)) {
                router.selectedDay = Date().startOfLocalDay
            }
        }
    }
}
