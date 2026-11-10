import UserNotifications

/// Sends a notification when the mouse's battery drops below the alert level and, with
/// reminders on, again each time it drops a step further. It starts over once charged back above it.
@MainActor
final class BatteryNotifier {
    /// The level the last notification was for, while the battery stays below the alert level.
    private var alertedAt: Int?

    func check(level: Int?, charging: Bool, settings: BatterySettings) {
        guard settings.alertsOn else { alertedAt = nil; return }
        // No mouse reporting right now, or it's on its cable: wait rather than starting over.
        guard let level, !charging else { return }
        guard level < Int(settings.alertLevel) else { alertedAt = nil; return }
        guard Self.isDue(level: level, alertedAt: alertedAt, remindStep: settings.remindsAgain ? Int(settings.reminderStep) : nil)
        else { return }
        alertedAt = level
        Self.send(level: level, sound: settings.alertSound)
    }

    /// Whether a battery below the alert level notifies now: the first time, and with reminders,
    /// once it's `remindStep` lower than the last notification.
    nonisolated static func isDue(level: Int, alertedAt: Int?, remindStep: Int?) -> Bool {
        guard let alertedAt else { return true }
        guard let remindStep else { return false }
        return level <= alertedAt - remindStep
    }

    /// The same notification, to see how it looks and how long it stays.
    static func sendTest(level: Int?, sound: Bool) {
        send(level: level ?? 15, sound: sound)
    }

    /// Asks for permission first: the alert can come on without the Battery tab, from an import.
    private static func send(level: Int, sound: Bool) {
        Task {
            guard await NotificationAccess.request() else { return }
            try? await NotificationAccess.center?.add(request(level: level, sound: sound))
        }
    }

    private static func request(level: Int, sound: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Mouse battery low")
        content.body = String(localized: "Your mouse is at \(level)%. Charge it soon.")
        content.sound = sound ? .default : nil
        return UNNotificationRequest(identifier: "mouse-battery-low", content: content, trigger: nil)
    }
}
