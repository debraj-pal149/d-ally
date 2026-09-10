import UIKit
import UserNotifications
import SwiftData
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        registerCategories()
        BGTaskScheduler.shared.register(forTaskWithIdentifier: NotificationIDs.bgRefresh, using: nil) { task in
            Self.handleRefresh(task as! BGAppRefreshTask)
        }
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        scheduleBackgroundRefresh()
        let context = ModelContext(Persistence.shared)
        NotificationSchedulingService.shared.rescheduleFromStore(context: context)
    }

    private func registerCategories() {
        let done = UNNotificationAction(identifier: NotificationIDs.actionDone, title: "Mark done", options: [])
        let skip = UNNotificationAction(identifier: NotificationIDs.actionSkip, title: "Skip today", options: [])
        let open = UNNotificationAction(identifier: NotificationIDs.actionOpen, title: "Open", options: [.foreground])
        let reminder = UNNotificationCategory(
            identifier: NotificationIDs.categoryReminder,
            actions: [done, skip, open],
            intentIdentifiers: [],
            options: []
        )
        let weeklyOpen = UNNotificationAction(identifier: NotificationIDs.actionOpen, title: "Open calendar", options: [.foreground])
        let weekly = UNNotificationCategory(
            identifier: NotificationIDs.categoryWeekly,
            actions: [weeklyOpen],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([reminder, weekly])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let taskId = (info["taskId"] as? String).flatMap(UUID.init(uuidString:))
        let dayKey = info["dayKey"] as? String

        switch response.actionIdentifier {
        case NotificationIDs.actionDone:
            if let taskId, let dayKey, let day = Date.date(fromDayKey: dayKey) {
                let context = ModelContext(Persistence.shared)
                DayLogService.markKept(taskId: taskId, day: day, in: context)
            }
        case NotificationIDs.actionSkip:
            if let taskId, let dayKey, let day = Date.date(fromDayKey: dayKey) {
                let context = ModelContext(Persistence.shared)
                DayLogService.markSkipped(taskId: taskId, day: day, in: context)
            }
        default:
            if let urlString = info["url"] as? String, let url = URL(string: urlString) {
                await MainActor.run {
                    NotificationCenter.default.post(name: .dallyOpenURL, object: url)
                }
            }
        }
    }

    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: NotificationIDs.bgRefresh)
        request.earliestBeginDate = Date().addingTimeInterval(3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(_ task: BGAppRefreshTask) {
        let context = ModelContext(Persistence.shared)
        NotificationSchedulingService.shared.rescheduleFromStore(context: context)
        AppDelegate().scheduleBackgroundRefresh()
        task.setTaskCompleted(success: true)
    }
}

extension Notification.Name {
    static let dallyOpenURL = Notification.Name("dallyOpenURL")
}

enum Persistence {
    static let shared: ModelContainer = {
        let schema = Schema([DailyTask.self, TaskDayLog.self])
        let config = ModelConfiguration("DAlly", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
