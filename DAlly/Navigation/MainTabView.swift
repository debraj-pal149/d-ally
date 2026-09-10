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

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(AppColors.aquaInk(scheme))
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
