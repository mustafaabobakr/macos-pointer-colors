import UserNotifications

/// Sends one notification each time the mouse's battery drops below the alert's level, and
/// another only once it has been charged back above it.
@MainActor
final class BatteryNotifier {
    private var hasAlerted = false

    func check(level: Int?, alert: BatteryAlert) {
        guard let threshold = alert.threshold else { hasAlerted = false; return }
        // No mouse reporting right now: wait for it rather than starting over.
        guard let level else { return }
        guard level < threshold else { hasAlerted = false; return }
        guard !hasAlerted else { return }
        hasAlerted = true
        Self.send(level: level)
    }

    /// The same notification, to see how it looks and how long it stays.
    static func sendTest(level: Int?) {
        send(level: level ?? 15)
    }

    /// Asks for permission first: the alert can come on without the Battery tab, from an import.
    private static func send(level: Int) {
        Task {
            guard await NotificationAccess.request() else { return }
            try? await NotificationAccess.center?.add(request(level: level))
        }
    }

    private static func request(level: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Mouse battery low")
        content.body = String(localized: "Your mouse is at \(level)%. Charge it soon.")
        content.sound = .default
        return UNNotificationRequest(identifier: "mouse-battery-low", content: content, trigger: nil)
    }
}
