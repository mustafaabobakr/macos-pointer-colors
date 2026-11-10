import SwiftUI

/// The low-battery notification: its level, its sound, reminders as the battery keeps
/// dropping, and a test.
struct BatteryAlertCard: View {
    @Bindable var battery: BatterySettings
    /// The mouse's level now, for the test notification.
    let level: Int?
    @State private var isExplaining = false
    @State private var notificationsBlocked = false

    var body: some View {
        SettingsCard("Low battery", anchor: "battery.low") {
            SettingsToggle("Notify me", symbol: "battery.25percent",
                           caption: "When the battery drops below the level, and again after it's charged.",
                           isOn: $battery.alertsOn.revealing())
                .featureSpot("clip-battery-alert")
            Reveal(isShown: battery.alertsOn) { alertRows }
            SettingsRow("Test notification", symbol: "bell.and.waves.left.and.right",
                        caption: "Shows the low-battery notification now, with your mouse's level.") {
                Button("Send Test") { Task { await sendTest() } }
            }
            .featureSpot("clip-battery-test")
            .notificationExplanation(isPresented: $isExplaining) { allowed in
                notificationsBlocked = !allowed
                if allowed { BatteryNotifier.sendTest(level: level, sound: battery.alertSound) }
            }
            Reveal(isShown: notificationsBlocked) {
                SettingsRow(symbol: "exclamationmark.triangle.fill",
                            title: Text("Notifications are off for Pointer Colors").foregroundStyle(.red),
                            caption: Text("Turn on Allow notifications in System Settings, then send the test again.")) {
                    Button("Open System Settings…", action: NotificationAccess.openSettings)
                }
            }
        }
        .animation(.reveal, value: notificationsBlocked)
        // Back from System Settings: drop the error once notifications are on.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard notificationsBlocked else { return }
            Task { notificationsBlocked = await NotificationAccess.current() == .denied }
        }
    }

    @ViewBuilder private var alertRows: some View {
        ValueSlider(title: String(localized: "Below"), symbol: "battery.0percent", value: $battery.alertLevel,
                    range: BatterySettings.levelRange, format: "%.0f%%", ends: .level)
        SettingsToggle("Sound", symbol: "speaker.wave.2", caption: "Plays the notification sound with it.",
                       isOn: $battery.alertSound)
        SettingsToggle("Remind me again", symbol: "bell.badge",
                       caption: "Notifies again as it keeps dropping, until it's charged.",
                       isOn: $battery.remindsAgain.revealing())
        Reveal(isShown: battery.remindsAgain) {
            ValueSlider(title: String(localized: "Every"), symbol: "arrow.down.to.line", value: $battery.reminderStep,
                        range: BatterySettings.reminderStepRange, format: "%.0f%% lower", step: 1, ends: .spread)
        }
    }

    /// Asks first when macOS hasn't yet, and says how to turn notifications on when they're off.
    private func sendTest() async {
        switch await NotificationAccess.current() {
        case .notAsked: isExplaining = true
        case .denied: notificationsBlocked = true
        case .allowed:
            notificationsBlocked = false
            BatteryNotifier.sendTest(level: level, sound: battery.alertSound)
        }
    }
}
