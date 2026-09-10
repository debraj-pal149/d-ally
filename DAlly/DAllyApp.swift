import SwiftUI
import SwiftData

@main
struct DAllyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var router = DeepLinkRouter()

    var body: some Scene {
        WindowGroup {
            ContentRootView()
                .environment(router)
                .modelContainer(Persistence.shared)
        }
    }
}
