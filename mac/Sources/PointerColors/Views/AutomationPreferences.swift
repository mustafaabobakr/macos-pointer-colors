import SwiftUI

/// Preferences › Automation: appearance pairs and shake to find. Per-display sizes live in the menu.
struct AutomationPreferences: View {
    let model: AppModel
    @State private var shakeToFind = false

    var body: some View {
        SettingsPage("Automation") {
            if model.needsFullDiskAccess {
                Text("Automation needs Full Disk Access. Grant it in General › Permission.")
                    .appFont(.caption).foregroundStyle(.orange)
            }
            Group {
                AppearanceSection(automation: model.automation, pairs: model.library.all)
                    .featureSpot("appearance-pairs")
                AppColorsSection(automation: model.automation, pairs: model.library.all)
                    .featureSpot("app-colors")
                SettingsCard("Finding the pointer", anchor: "automation.finding") {
                    SettingsToggle("Shake mouse pointer to locate", symbol: "arrow.left.and.right",
                                   caption: "Move the pointer back and forth quickly to make it bigger for a moment.",
                                   isOn: Binding(get: { shakeToFind }, set: { shakeToFind = $0; model.setShakeToFind($0) }))
                        .disabled(model.shakeToFind == nil)
                    PointerLocationRows(locator: model.locator)
                }
                .featureSpot("pointer-location")
                HoverFocusSection(hoverFocus: model.hoverFocus)
            }
            .disabled(model.needsFullDiskAccess)
        }
        .onAppear { shakeToFind = model.shakeToFind ?? false }
    }
}

/// Press a modifier key twice to see a ring close in on the pointer.
private struct PointerLocationRows: View {
    @Bindable var locator: PointerLocator

    var body: some View {
        SettingsToggle(title: Text("Show pointer location"), symbol: "scope",
                       caption: Text("Press \(locator.key.title) twice to reveal the pointer."), isOn: $locator.isOn)
            .featureSpot("clip-pointer-location")
        if locator.isOn {
            SettingsRow("Key", symbol: "keyboard") {
                Picker("Key", selection: $locator.key) {
                    ForEach(PointerLocator.keys, id: \.rawValue) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
                .featureSpot("clip-pointer-location-key")
                Button("Show Now") { locator.reveal() }
            }
        }
    }
}

/// The window under the pointer takes keyboard focus, without coming to the front.
private struct HoverFocusSection: View {
    @Bindable var hoverFocus: HoverFocus

    var body: some View {
        AccessibilityNotice(isNeeded: hoverFocus.isOn)
        SettingsCard("Windows", anchor: "automation.windows") {
            SettingsToggle("Focus the window under the pointer", symbol: "macwindow",
                           caption: "Type into a window just by pointing at it; it stays where it is. Hold a modifier key to move across windows without changing focus.",
                           isOn: $hoverFocus.isOn)
                .disabled(!hoverFocus.isAvailable)
                .featureSpot("clip-hover-focus")
        }
        .featureSpot("hover-focus")
    }
}

private struct AppearanceSection: View {
    @Bindable var automation: Automation
    let pairs: [PointerPair]

    var body: some View {
        SettingsCard("Appearance", anchor: "automation.appearance") {
            SettingsToggle("Switch pairs with light and dark appearance", symbol: "circle.lefthalf.filled",
                           caption: "Applies a pair whenever macOS changes appearance, including on a schedule.",
                           isOn: $automation.followsAppearance)
                .featureSpot("clip-follows-appearance")
            pairPicker("Light appearance", symbol: "sun.max", selection: $automation.lightPairID)
            pairPicker("Dark appearance", symbol: "moon", selection: $automation.darkPairID)
        }
    }

    private func pairPicker(_ title: LocalizedStringKey, symbol: String, selection: Binding<String>) -> some View {
        SettingsRow(title, symbol: symbol) {
            PairMenuButton(selection: Binding(get: { selection.wrappedValue }, set: { if let id = $0 { selection.wrappedValue = id } }),
                           pairs: pairs, accessibilityTitle: String(localized: "Pair for this appearance"), allowsNone: false)
                .fixedSize()
        }
        .disabled(!automation.followsAppearance)
    }
}
