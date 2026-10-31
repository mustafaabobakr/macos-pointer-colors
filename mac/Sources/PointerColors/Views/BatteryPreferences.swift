import SwiftUI

/// Everything about the mouse's battery: where its level shows and when to be told it's low.
struct BatteryPreferences: View {
    @Bindable var model: AppModel
    @State private var isExplaining = false
    @State private var notificationsBlocked = false

    var body: some View {
        SettingsPage("Battery") {
            SettingsCard(anchor: "battery.level") {
                SettingsRow("Your mouse", symbol: "computermouse") {
                    Text(levelText).monospacedDigit()
                }
            }
            SettingsCard("Show the level", anchor: "battery.show") {
                SettingsMenu(title: Text("Next to the menu-bar icon"), symbol: "menubar.rectangle",
                             caption: model.menuBarVisibility == .never ? Text("The menu-bar icon is hidden in General.") : nil,
                             selection: $model.batteryDisplay) {
                    ForEach(BatteryDisplay.allCases) { Text($0.title).tag($0) }
                }
                .disabled(model.menuBarVisibility == .never)
                .featureSpot("clip-battery")
                SettingsMenu(title: Text("On the Dock icon"), symbol: "dock.rectangle",
                             caption: model.showsInDock ? nil : Text("Turn on Show in Dock in General to see it."),
                             selection: $model.dockBattery) {
                    ForEach(BatteryDisplay.allCases) { Text($0.title).tag($0) }
                }
                .disabled(!model.showsInDock)
                .featureSpot("clip-dock-battery")
                SettingsMenu(title: Text("Under the pointer"), symbol: "cursorarrow",
                             caption: Text("A small label that follows the pointer."),
                             selection: $model.pointerBattery) {
                    ForEach(BatteryDisplay.allCases) { Text($0.title).tag($0) }
                }
                .featureSpot("clip-pointer-battery")
            }
            SettingsCard("Low battery", anchor: "battery.low") {
                SettingsMenu(title: Text("Notify me"), symbol: "battery.25percent", caption: Text(alertCaption),
                             selection: $model.batteryAlert) {
                    ForEach(BatteryAlert.allCases) { Text($0.title).tag($0) }
                }
                .featureSpot("clip-battery-alert")
                SettingsRow("Test notification", symbol: "bell.and.waves.left.and.right",
                            caption: "Shows the low-battery notification now, with your mouse's level.") {
                    Button("Send Test") { Task { await sendTest() } }
                }
                .featureSpot("clip-battery-test")
                .notificationExplanation(isPresented: $isExplaining) { allowed in
                    notificationsBlocked = !allowed
                    if allowed { BatteryNotifier.sendTest(level: model.tracking.batteryLevel) }
                }
                if notificationsBlocked {
                    SettingsRow(symbol: "exclamationmark.triangle.fill",
                                title: Text("Notifications are off for Pointer Colors").foregroundStyle(.red),
                                caption: Text("Turn on Allow notifications in System Settings, then send the test again.")) {
                        Button("Open System Settings…", action: NotificationAccess.openSettings)
                    }
                }
            }
            BatteryHistoryCard(model: model)
        }
        .featureSpot("battery")
        .onAppear { model.tracking.refreshBattery() }
        // Back from System Settings: drop the error once notifications are on.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard notificationsBlocked else { return }
            Task { notificationsBlocked = await NotificationAccess.current() == .denied }
        }
    }

    /// Asks first when macOS hasn't yet, and says how to turn notifications on when they're off.
    private func sendTest() async {
        switch await NotificationAccess.current() {
        case .notAsked: isExplaining = true
        case .denied: notificationsBlocked = true
        case .allowed:
            notificationsBlocked = false
            BatteryNotifier.sendTest(level: model.tracking.batteryLevel)
        }
    }

    private var levelText: String {
        guard let level = model.tracking.batteryLevel else { return String(localized: "No battery reported") }
        return String(localized: "\(level)%")
    }

    private let alertCaption = String(localized: "Once each time it drops below the level, again after it's charged.")
}
