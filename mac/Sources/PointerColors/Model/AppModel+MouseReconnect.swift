import Foundation

extension AppModel {
    /// Opening the menu reconnects the mouse when that's on, and otherwise only reads its state.
    func reconnectMouseOnMenuOpen() {
        guard reconnectsMouseOnMenuOpen else { return mouseReconnect.refresh() }
        Task { await mouseReconnect.reconnect() }
    }

    /// Reconnect now, from the menu or Preferences › General › Mouse.
    func reconnectMouse() {
        Task { await mouseReconnect.reconnect() }
    }
}
