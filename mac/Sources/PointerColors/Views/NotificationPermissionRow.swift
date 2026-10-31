import SwiftUI

/// Notification permission: says what the app uses it for before macOS asks, and how long the
/// low-battery notification stays on screen once it's allowed.
struct NotificationPermissionRow: View {
    @State private var access: NotificationAccess?
    @State private var isExplaining = false

    var body: some View {
        SettingsRow("Notifications", symbol: "bell", caption: "Only to tell you when your mouse's battery is low.") {
            control
        }
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refresh() }
        }
        .notificationExplanation(isPresented: $isExplaining) { _ in await refresh() }
        if case .allowed(let staysOnScreen) = access {
            SettingsRow(staysOnScreen ? "Stays on screen until you close it" : "Goes away after a few seconds", symbol: "bell.badge",
                        caption: "macOS sets this: choose Alerts in System Settings to keep it, Banners to let it go.") {
                Button("Change…", action: NotificationAccess.openSettings)
            }
        }
    }

    @ViewBuilder private var control: some View {
        switch access {
        case .notAsked: Button("Allow…") { isExplaining = true }
        case .denied: Button("Open System Settings…", action: NotificationAccess.openSettings)
        case .allowed: Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(.green)
        case nil: EmptyView()
        }
    }

    private func refresh() async {
        access = await NotificationAccess.current()
    }
}

extension View {
    /// Says why the app wants notifications, then shows macOS's prompt on Continue and passes on
    /// whether they were allowed.
    func notificationExplanation(isPresented: Binding<Bool>, then: @escaping @MainActor (Bool) async -> Void) -> some View {
        alert("Allow notifications?", isPresented: isPresented) {
            Button("Continue") { Task { await then(await NotificationAccess.request()) } }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Pointer Colors sends one when your mouse's battery drops below the level you chose in Battery, and nothing else. macOS asks next.")
        }
    }
}
