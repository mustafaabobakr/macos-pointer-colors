import AppKit
import SwiftUI

/// Preferences › General › Permissions: every permission the app uses, under the feature that
/// needs it, each saying why and whether it's allowed. Add a row here with every new one.
struct PermissionsCard: View {
    @Bindable var model: AppModel
    /// Read again whenever the app comes forward, as the user may have just changed them.
    @State private var accessibility = AXIsProcessTrusted()
    @State private var screenRecording = ScreenRecordingAccess.isAllowed

    var body: some View {
        SettingsCard("Permissions", anchor: "general.permission") {
            PermissionGroup("Pointer colors and size") {
                SettingsRow("Full Disk Access", symbol: "lock.shield",
                            caption: "macOS keeps the pointer's colors and size in a protected settings file, and only Full Disk Access lets the app write it.") {
                    PermissionStatus(isAllowed: !model.needsFullDiskAccess, action: model.openFullDiskAccessSettings)
                }
            }
            PermissionGroup("Mouse buttons and laser") {
                SettingsRow("Accessibility", symbol: "accessibility",
                            caption: "Lets the app see mouse events before other apps do: side buttons and swipes go back and forward, accidental double-clicks are dropped, windows focus under the pointer, and the laser draws without clicking.") {
                    PermissionStatus(isAllowed: accessibility) { MouseEventTap.shared.requestAccess() }
                }
            }
            PermissionGroup("Laser screenshots") {
                SettingsRow("Screen Recording", symbol: "rectangle.dashed.badge.record",
                            caption: "Captures the area around each laser drawing, only while Take a screenshot of each drawing is on. Nothing is recorded otherwise.") {
                    PermissionStatus(isAllowed: screenRecording, action: ScreenRecordingAccess.request)
                }
            }
            PermissionGroup("Magic Mouse smart zoom") {
                SettingsRow("Screen Recording", symbol: "plus.magnifyingglass",
                            caption: "Draws the zoom from a live picture of the screen, only while zoomed in. Nothing is saved or sent anywhere.") {
                    PermissionStatus(isAllowed: screenRecording, action: ScreenRecordingAccess.request)
                }
            }
            PermissionGroup("Battery alerts") {
                NotificationPermissionRow()
            }
        }
        .animation(.reveal, value: model.needsFullDiskAccess)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        accessibility = AXIsProcessTrusted()
        screenRecording = ScreenRecordingAccess.isAllowed
    }
}

/// The permissions one feature needs, under its name.
private struct PermissionGroup<Rows: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder var rows: Rows
    @Environment(\.appTextScale) private var scale

    init(_ label: LocalizedStringKey, @ViewBuilder rows: () -> Rows) {
        self.label = label
        self.rows = rows()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            Text(label)
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            rows
        }
        .padding(.top, 4 * scale)
    }
}

/// Allowed, in green, or a button that asks for it.
private struct PermissionStatus: View {
    let isAllowed: Bool
    let action: () -> Void

    var body: some View {
        if isAllowed {
            Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(.green)
        } else {
            Button("Allow…", action: action)
        }
    }
}
