import SwiftUI

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
