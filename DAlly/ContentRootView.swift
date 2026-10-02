import SwiftData
import SwiftUI

struct ContentRootView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKey.welcomeSeen) private var welcomeSeen = false
    @AppStorage(AppStorageKey.appearanceMode) private var appearanceMode = AppDefaults.appearanceMode

    private var auth: AuthService { AuthService.shared }
    private var sync: SyncEngine { SyncEngine.shared }

    var body: some View {
        @Bindable var router = router
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else if welcomeSeen {
                ProfileSetupView()
            } else {
                WelcomeView()
            }
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.preferredColorScheme)
        .sheet(isPresented: $router.showTaskEditor) {
            TaskEditorView(taskId: router.editingTaskId)
        }
        .sheet(isPresented: $router.showBookmarkEditor) {
            BookmarkEditorView(bookmarkId: router.editingBookmarkId, day: router.bookmarkEditorDay)
        }
        .sheet(item: $router.taskActionPrompt) { prompt in
            CompletionPromptSheet(taskId: prompt.taskId, day: prompt.day)
        }
        .sheet(isPresented: $router.showNotificationPriming) {
            NotificationPrimingView()
        }
        .sheet(isPresented: mergeSheetShown) {
            MergeProgressSheet()
        }
        .alert(AppCopy.profileMergeTitle, isPresented: mergeChoiceShown) {
            Button(AppCopy.profileMergeAdd) { auth.resolveMergeChoice(addLocal: true) }
            Button(AppCopy.profileMergeRemove, role: .destructive) { auth.resolveMergeChoice(addLocal: false) }
        } message: {
            Text(mergeChoiceMessage)
        }
        .onOpenURL { url in
            if auth.handleOpenURL(url) { return }
            router.apply(url: url)
        }
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
            Persistence.repairStoppedHabitsIfNeeded(in: modelContext)
            NotificationSchedulingService.shared.rescheduleFromStore(context: modelContext)
            offerNotificationPermissionIfNeeded()
            if UserDefaults.standard.bool(forKey: "seedPreviewData") {
                PreviewSampleData.seedIfNeeded(into: modelContext)
                UserDefaults.standard.set(false, forKey: "seedPreviewData")
            }
            if let tab = UserDefaults.standard.string(forKey: "bootTab") {
                switch tab {
                case "calendar": router.selectedTab = .calendar
                case "settings": router.selectedTab = .settings
                case "profile": router.selectedTab = .profile
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

    /// Alerts default on in-app, but iOS still needs one Allow tap. Offer that once
    /// when the person already has habits and we have never asked on this install.
    private func offerNotificationPermissionIfNeeded() {
        guard hasCompletedOnboarding else { return }
        let masterOn = UserDefaults.standard.object(forKey: AppStorageKey.notificationsMasterEnabled) as? Bool
            ?? AppDefaults.notificationsMasterEnabled
        guard masterOn else { return }
        let alreadyAsked = UserDefaults.standard.bool(forKey: AppStorageKey.hasRequestedNotificationPermission)
        guard !alreadyAsked else { return }
        let habits = (try? modelContext.fetch(FetchDescriptor<DailyTask>())) ?? []
        guard habits.contains(where: { $0.notificationsEnabled && $0.isLive }) else { return }

        Task { @MainActor in
            let state = await NotificationPermissionService.shared.currentState()
            guard state == .notDetermined else { return }
            // Let the first frame settle so this does not fight other sheets.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !router.showNotificationPriming,
                  router.taskActionPrompt == nil,
                  !router.showTaskEditor,
                  !router.showBookmarkEditor else { return }
            router.showNotificationPriming = true
        }
    }

    private var mergeSheetShown: Binding<Bool> {
        Binding(
            get: { sync.mergeInProgress || sync.mergeSummary != nil },
            set: { shown in
                if !shown { sync.mergeSummary = nil }
            }
        )
    }

    private var mergeChoiceShown: Binding<Bool> {
        Binding(
            get: { auth.pendingMergeChoice != nil },
            set: { _ in }
        )
    }

    private var mergeChoiceMessage: String {
        let count = auth.pendingMergeChoice?.habitCount ?? 0
        let habits = count == 1 ? "1 habit" : "\(count) habits"
        return "\(AppCopy.profileMergeBody) Add the \(habits) to this profile, or remove them from this phone. The other profile keeps its copy."
    }
}
