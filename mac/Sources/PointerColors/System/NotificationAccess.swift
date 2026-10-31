import AppKit
import UserNotifications

/// Whether macOS lets the app send notifications, and how long they stay on screen. macOS keeps
/// both: the app can only ask once, and the style is chosen in System Settings › Notifications.
enum NotificationAccess: Equatable {
    case notAsked
    case denied
    /// `staysOnScreen` is the Alerts style, which waits to be dismissed; Banners go by themselves.
    case allowed(staysOnScreen: Bool)

    /// The notification center, or nil in the bare build (no app bundle), where asking for it crashes.
    static var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    static func current() async -> Self {
        guard let center else { return .notAsked }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notAsked
        case .denied: return .denied
        default: return .allowed(staysOnScreen: settings.alertStyle == .alert)
        }
    }

    /// Shows macOS's own prompt, once; later calls return what the user chose then.
    static func request() async -> Bool {
        (try? await center?.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Pointer Colors' page in System Settings › Notifications.
    @MainActor static func openSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")!
        NSWorkspace.shared.open(url)
    }
}
