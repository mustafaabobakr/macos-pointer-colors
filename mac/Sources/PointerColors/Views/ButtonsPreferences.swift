import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Preferences › Buttons: side buttons that go back and forward, and a fix for a worn button.
struct ButtonsPreferences: View {
    @Bindable var buttons: MouseButtons

    var body: some View {
        Form {
            AccessibilityNotice(isNeeded: buttons.sideButtonsNavigate || buttons.fixesDoubleClicks)
            Section("Side buttons") {
                Toggle(isOn: $buttons.sideButtonsNavigate) {
                    Text("Back and forward in every app")
                    Text("The mouse's side buttons go back and forward in Safari, Finder, Music and other apps that ignore them. Browsers like Chrome already follow them.")
                }
                .featureSpot("clip-side-buttons")
            }
            .featureSpot("side-buttons")
            if buttons.sideButtonsNavigate {
                NavigationAppsSection(buttons: buttons)
            }
            Section {
                Toggle(isOn: $buttons.fixesDoubleClicks) {
                    Text("Fix accidental double-clicks")
                    Text("A worn button can click twice when you press once. This ignores a second click that comes too soon after the first.")
                }
                .featureSpot("clip-double-clicks")
                if buttons.fixesDoubleClicks {
                    LabeledContent {
                        HStack {
                            Slider(value: $buttons.doubleClickWindow, in: MouseButtons.doubleClickWindowRange)
                                .accessibilityLabel("Ignore clicks within")
                                .featureSpot("clip-double-click-window")
                            Text("\(Int((buttons.doubleClickWindow * 1000).rounded())) ms").monospacedDigit()
                                .foregroundStyle(.secondary).frame(minWidth: 52, alignment: .trailing)
                        }
                        .frame(width: 280)
                    } label: {
                        Text("Ignore clicks within")
                        Text("Raise it if double clicks still get through; lower it if your own fast double-clicks are lost.")
                    }
                }
            } header: {
                Text("Clicks")
            }
            .featureSpot("double-clicks")
        }
        .formStyle(.grouped)
    }
}

/// Apps whose back and forward are keys, like Slack's ⌘[ and ⌘], so the side buttons press them.
private struct NavigationAppsSection: View {
    @Bindable var buttons: MouseButtons

    var body: some View {
        Section {
            ForEach(buttons.navigationApps) { app in
                NavigationAppRow(app: app) { change in
                    buttons.changeNavigationApp(app.id, change)
                } remove: {
                    buttons.removeNavigationApp(app.id)
                }
            }
            Button("Add App…", action: chooseApp).featureSpot("clip-side-button-apps")
        } header: {
            Text("Apps with their own back and forward keys")
        } footer: {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { app.isOn }, set: { isOn in change { $0.isOn = isOn } })) {
                Label { Text(app.name) } icon: { AppIcon(bundleID: app.bundleID) }
            }
            HStack(spacing: 16) {
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
        }
        .padding(.vertical, 4)
    }
}

/// An app's icon, small, or a generic one when it isn't installed.
private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application))
            .resizable()
            .frame(width: 32, height: 32)
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
            Section {
                LabeledContent {
                    Button("Allow…") { tap.requestAccess() }
                } label: {
                    Label("Needs Accessibility", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("Turn on Pointer Colors in System Settings › Privacy & Security › Accessibility. It starts working as soon as you do.")
                }
            }
        } else if isNeeded && !tap.isRunning {
            Section {
                LabeledContent {
                    Button("Relaunch") { try? AppUpdater.relaunch(); NSApp.terminate(nil) }
                } label: {
                    Label("Relaunch to finish", systemImage: "arrow.clockwise.circle.fill").foregroundStyle(.orange)
                    Text("Accessibility is on. macOS lets Pointer Colors watch clicks once it opens again.")
                }
            }
        }
    }
}
