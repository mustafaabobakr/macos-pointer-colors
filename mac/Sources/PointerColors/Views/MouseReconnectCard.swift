import SwiftUI

/// Preferences › General › Mouse: reconnecting a paired Apple mouse or trackpad over Bluetooth.
struct MouseReconnectCard: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsCard("Mouse", anchor: "general.mouse") {
            SettingsToggle("Reconnect my Apple mouse when I open the menu", symbol: "cursorarrow.motionlines",
                           caption: "Also reconnects a Magic Trackpad. Devices that are already connected are left alone.",
                           isOn: $model.reconnectsMouseOnMenuOpen)
                .resettable($model.reconnectsMouseOnMenuOpen, to: AppSettings.factory.reconnectsMouseOnMenuOpen)
            SettingsRow(symbol: "dot.radiowaves.left.and.right", title: Text("Bluetooth mouse"),
                        caption: Text(verbatim: reconnect.state.message)) {
                action
            }
        }
        .animation(.reveal, value: reconnect.state)
        .onAppear(perform: reconnect.refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            reconnect.refresh()
        }
    }

    private var reconnect: BluetoothReconnector { model.mouseReconnect }

    @ViewBuilder private var action: some View {
        if reconnect.state == .noAccess {
            Button("Open System Settings…", action: BluetoothReconnector.openSettings)
        } else {
            Button("Reconnect now", action: model.reconnectMouse)
                .disabled(reconnect.state.isBusy)
        }
    }
}
