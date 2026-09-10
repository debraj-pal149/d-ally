import Foundation
import UserNotifications

enum NotificationAuthState: String {
    case authorized, denied, notDetermined, provisional, ephemeral

    var displayName: String {
        switch self {
        case .authorized: "Authorized"
        case .denied: "Denied"
        case .notDetermined: "Not asked"
        case .provisional: "Provisional"
        case .ephemeral: "Ephemeral"
        }
    }
}

@MainActor
final class NotificationPermissionService {
    static let shared = NotificationPermissionService()
    private init() {}

    func currentState() async -> NotificationAuthState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        @unknown default: return .notDetermined
        }
    }

    func request() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            UserDefaults.standard.set(true, forKey: AppStorageKey.hasRequestedNotificationPermission)
            return granted
        } catch {
            UserDefaults.standard.set(true, forKey: AppStorageKey.hasRequestedNotificationPermission)
            return false
        }
    }
}
