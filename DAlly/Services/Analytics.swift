import Foundation
import SwiftData
#if canImport(Mixpanel)
import Mixpanel
#endif

/// Thin Mixpanel facade. No-ops in the widget extension and when Mixpanel is unavailable.
enum Analytics {
    private static let activatedKey = "analytics.activated"
    nonisolated(unsafe) private static var isReady = false

    #if DEBUG
    private static let tokenKey = "MixpanelDevToken"
    private static let buildConfig = "debug"
    #else
    private static let tokenKey = "MixpanelProdToken"
    private static let buildConfig = "release"
    #endif

    /// Filled from DAlly/Config/Mixpanel.xcconfig at build time. Empty if that file is missing.
    private static var token: String {
        let value = Bundle.main.object(forInfoDictionaryKey: tokenKey) as? String ?? ""
        if value.hasPrefix("$(") { return "" }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    static func configure() {
        #if canImport(Mixpanel)
        guard !SharedSettings.isExtension else { return }
        guard !token.isEmpty else { return }
        Mixpanel.initialize(token: token, trackAutomaticEvents: false)
        isReady = true
        #if DEBUG
        Mixpanel.mainInstance().loggingEnabled = true
        #endif
        DayLogService.onAnalytics = { status, source, day in
            switch status {
            case "kept", "skipped":
                habitMarked(status: status, source: source, day: day)
            case "cleared":
                habitLogCleared(source: source, day: day)
            default:
                break
            }
        }
        registerSuperProperties()
        track("app_opened")
        #endif
    }

    /// Safe from any thread / ViewBuilder context.
    nonisolated static func track(_ event: String, _ properties: [String: String] = [:]) {
        #if canImport(Mixpanel)
        guard isReady, !SharedSettings.isExtension else { return }
        Mixpanel.mainInstance().track(event: event, properties: properties)
        #endif
    }

    @MainActor
    static func identify(uid: String, provider: String) {
        #if canImport(Mixpanel)
        guard isReady, !SharedSettings.isExtension else { return }
        Mixpanel.mainInstance().identify(distinctId: uid)
        peopleSet([
            "auth_state": "signed_in",
            "auth_provider": provider,
        ])
        registerSuperProperties()
        #endif
    }

    @MainActor
    static func resetIdentity() {
        #if canImport(Mixpanel)
        guard isReady, !SharedSettings.isExtension else { return }
        Mixpanel.mainInstance().reset()
        peopleSet([
            "auth_state": "guest",
            "auth_provider": "none",
        ])
        registerSuperProperties()
        #endif
    }

    nonisolated static func peopleSet(_ properties: [String: String]) {
        #if canImport(Mixpanel)
        guard isReady, !SharedSettings.isExtension else { return }
        Mixpanel.mainInstance().people.set(properties: properties)
        #endif
    }

    nonisolated static func peopleIncrement(_ property: String, by amount: Double = 1) {
        #if canImport(Mixpanel)
        guard isReady, !SharedSettings.isExtension else { return }
        Mixpanel.mainInstance().people.increment(property: property, by: amount)
        #endif
    }

    nonisolated static func syncCounts(habits: Int, bookmarks: Int) {
        peopleSet([
            "habit_count_live": String(habits),
            "bookmark_count_live": String(bookmarks),
        ])
        #if canImport(Mixpanel)
        guard !SharedSettings.isExtension else { return }
        guard isReady else { return }
        Mixpanel.mainInstance().registerSuperProperties(["habit_count_live": String(habits)])
        #endif
    }

    @MainActor
    static func syncCounts(from context: ModelContext) {
        let tasks = (try? context.fetch(FetchDescriptor<DailyTask>())) ?? []
        let bookmarks = (try? context.fetch(FetchDescriptor<DayBookmark>())) ?? []
        syncCounts(
            habits: tasks.filter(\.isLive).count,
            bookmarks: bookmarks.filter(\.isLive).count
        )
    }

    nonisolated static func setNotificationsMaster(_ on: Bool) {
        peopleSet(["notifications_master_on": on ? "true" : "false"])
    }

    nonisolated static func markActivatedIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: activatedKey) else { return }
        UserDefaults.standard.set(true, forKey: activatedKey)
        peopleSet([
            "activated": "true",
            "activated_at": ISO8601DateFormatter().string(from: Date()),
        ])
    }

    // MARK: - Typed helpers

    nonisolated static func habitMarked(status: String, source: String, day: Date) {
        let dayKind = DaySectioningService.kind(of: day).analyticsName
        let event = status == "kept" ? "habit_marked_kept" : "habit_skipped"
        track(event, [
            "source": source,
            "day_kind": dayKind,
        ])
        if status == "kept" {
            peopleIncrement("lifetime_kept")
        } else {
            peopleIncrement("lifetime_skipped")
        }
        peopleSet(["last_action_at": ISO8601DateFormatter().string(from: Date())])
        markActivatedIfNeeded()
    }

    nonisolated static func habitLogCleared(source: String, day: Date) {
        track("habit_log_cleared", [
            "source": source,
            "day_kind": DaySectioningService.kind(of: day).analyticsName,
        ])
    }

    @MainActor
    private static func registerSuperProperties(habitCount: Int? = nil) {
        #if canImport(Mixpanel)
        guard isReady, !SharedSettings.isExtension else { return }
        var props: [String: String] = [
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "build_config": buildConfig,
            "auth_state": AuthService.shared.isSignedIn ? "signed_in" : "guest",
        ]
        if let habitCount {
            props["habit_count_live"] = String(habitCount)
        }
        Mixpanel.mainInstance().registerSuperProperties(props)
        peopleSet([
            "app_version": props["app_version"] ?? "unknown",
            "build_config": buildConfig,
            "auth_state": props["auth_state"] ?? "guest",
        ])
        #endif
    }
}

private extension DayKind {
    var analyticsName: String {
        switch self {
        case .past: "past"
        case .today: "today"
        case .future: "future"
        }
    }
}
