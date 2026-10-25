import SwiftUI

struct MainTabView: View {
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.colorScheme) private var scheme

    private var daySymbol: String {
        Date.isSameLocalDay(router.selectedDay, Date()) ? "sun.max" : "checklist"
    }

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            DayPagerView()
                .tabItem { Label("Day", systemImage: daySymbol) }
                .tag(AppTab.day)

            MonthCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(AppTab.calendar)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(AppColors.aquaInk(scheme))
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .onChange(of: router.selectedTab) { _, tab in
            Analytics.track("tab_selected", ["tab": tab.analyticsName])
        }
    }
}

private extension AppTab {
    var analyticsName: String {
        switch self {
        case .day: "day"
        case .calendar: "calendar"
        case .profile: "profile"
        case .settings: "settings"
        }
    }
}
