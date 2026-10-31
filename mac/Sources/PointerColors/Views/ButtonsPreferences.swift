import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Preferences › Buttons: side buttons that go back and forward, and a fix for a worn button.
struct ButtonsPreferences: View {
    @Bindable var buttons: MouseButtons

    var body: some View {
        SettingsPage("Buttons") {
            AccessibilityNotice(isNeeded: buttons.sideButtonsNavigate || buttons.fixesDoubleClicks)
            SettingsCard("Side buttons", anchor: "buttons.side") {
                SettingsToggle("Back and forward in every app", symbol: "arrow.left.arrow.right",
                               caption: "The mouse's side buttons go back and forward in Safari, Finder, Music and other apps that ignore them. Browsers like Chrome already follow them.",
                               isOn: $buttons.sideButtonsNavigate)
                    .featureSpot("clip-side-buttons")
            }
            .featureSpot("side-buttons")
            if buttons.sideButtonsNavigate {
                NavigationAppsSection(buttons: buttons)
            }
            SettingsCard("Clicks", anchor: "buttons.clicks") {
                SettingsToggle("Fix accidental double-clicks", symbol: "cursorarrow.click.2",
                               caption: "A worn button can click twice when you press once. This ignores a second click that comes too soon after the first.",
                               isOn: $buttons.fixesDoubleClicks)
                    .featureSpot("clip-double-clicks")
                if buttons.fixesDoubleClicks {
                    SettingsRow("Ignore clicks within", symbol: "timer",
                                caption: "Raise it if double clicks still get through; lower it if your own fast double-clicks are lost.") {
                        HStack {
                            Slider(value: $buttons.doubleClickWindow, in: MouseButtons.doubleClickWindowRange)
                                .accessibilityLabel("Ignore clicks within")
                                .featureSpot("clip-double-click-window")
                            Text("\(Int((buttons.doubleClickWindow * 1000).rounded())) ms").monospacedDigit()
                                .foregroundStyle(.secondary).frame(minWidth: 52, alignment: .trailing)
                        }
                        .frame(width: 280)
                    }
                }
            }
            .featureSpot("double-clicks")
        }
    }
}

/// Apps whose back and forward are keys, like Slack's ⌘[ and ⌘], so the side buttons press them.
private struct NavigationAppsSection: View {
    @Bindable var buttons: MouseButtons

    var body: some View {
        SettingsCard("Apps with their own back and forward keys", anchor: "buttons.apps") {
            ForEach(buttons.navigationApps) { app in
                NavigationAppRow(app: app) { change in
                    buttons.changeNavigationApp(app.id, change)
                } remove: {
                    buttons.removeNavigationApp(app.id)
                }
            }
            Button("Add App…", action: chooseApp).featureSpot("clip-side-button-apps")
            Text("In these apps the side buttons, and swiping sideways on a Magic Mouse, press the app's back and forward shortcuts.")
                .appFont(.caption).foregroundStyle(.secondary)
        }
        .featureSpot("side-button-apps")
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        buttons.addNavigationApp(at: url)
    }
}

/// One listed app: its name and an on/off switch, with its back and forward keys and Remove below.
private struct NavigationAppRow: View {
    let app: NavigationApp
    let change: ((inout NavigationApp) -> Void) -> Void
    let remove: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { app.isOn }, set: { isOn in change { $0.isOn = isOn } })) {
                Label { Text(app.name) } icon: { AppIcon(bundleID: app.bundleID) }
            }
            HStack(spacing: 16 * scale) {
                LabeledContent("Back") {
                    ShortcutRecorder(combo: app.back) { combo in change { $0.back = combo } }
                }
                .disabled(!app.isOn)
                LabeledContent("Forward") {
                    ShortcutRecorder(combo: app.forward) { combo in change { $0.forward = combo } }
                }
                .disabled(!app.isOn)
                Spacer()
                Button("Remove", role: .destructive, action: remove)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, settingsRowTextInset(scale))
        }
    }
}

/// An app's icon, small, or a generic one when it isn't installed.
private struct AppIcon: View {
    let bundleID: String
    @Environment(\.appTextScale) private var scale

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application))
            .resizable()
            .frame(width: 26 * scale, height: 26 * scale)
            .accessibilityHidden(true)
    }
}

/// Says when a feature that's on waits for Accessibility, with a button to allow it.
struct AccessibilityNotice: View {
    let isNeeded: Bool
    private let tap = MouseEventTap.shared

    var body: some View {
        // A feature clip never starts the tap, so it would always show the notice.
        if ScreenshotRenderer.isRendering {
            EmptyView()
        } else if isNeeded && !tap.isTrusted {
            SettingsCard {
                SettingsRow(symbol: "exclamationmark.triangle.fill", title: Text("Needs Accessibility").foregroundStyle(.orange),
                            caption: Text("Turn on Pointer Colors in System Settings › Privacy & Security › Accessibility. It starts working as soon as you do.")) {
                    Button("Allow…") { tap.requestAccess() }
                }
            }
        } else if isNeeded && !tap.isRunning {
            SettingsCard {
                SettingsRow(symbol: "arrow.clockwise.circle.fill", title: Text("Relaunch to finish").foregroundStyle(.orange),
                            caption: Text("Accessibility is on. macOS lets Pointer Colors watch clicks once it opens again.")) {
                    Button("Relaunch") { try? AppUpdater.relaunch(); NSApp.terminate(nil) }
                }
            }
        }
    }
}
