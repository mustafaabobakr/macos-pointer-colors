import SwiftUI

/// Preferences › Automation: appearance pairs and shake to find. Per-display sizes live in the menu.
struct AutomationPreferences: View {
    let model: AppModel
    @State private var shakeToFind = false

    var body: some View {
        Form {
            AppearanceSection(automation: model.automation, pairs: model.library.all)
                .featureSpot("appearance-pairs")
            AppColorsSection(automation: model.automation, pairs: model.library.all)
                .featureSpot("app-colors")
            Section("Finding the pointer") {
                Toggle(isOn: Binding(get: { shakeToFind }, set: { shakeToFind = $0; model.setShakeToFind($0) })) {
                    Text("Shake mouse pointer to locate")
                    Text("Move the pointer back and forth quickly to make it bigger for a moment.")
                }
                .disabled(model.shakeToFind == nil)
                PointerLocationRows(locator: model.locator)
            }
            .featureSpot("pointer-location")
            HoverFocusSection(hoverFocus: model.hoverFocus)
        }
        .formStyle(.grouped)
        .disabled(model.needsFullDiskAccess)
        .overlay(alignment: .top) {
            if model.needsFullDiskAccess {
                Text("Automation needs Full Disk Access. Grant it in General › Permission.")
                    .appFont(.caption).foregroundStyle(.orange).padding(.top, 4)
            }
        }
        .onAppear { shakeToFind = model.shakeToFind ?? false }
    }
}

/// Press a modifier key twice to see a ring close in on the pointer.
private struct PointerLocationRows: View {
    @Bindable var locator: PointerLocator

    var body: some View {
        Toggle(isOn: $locator.isOn) {
            Text("Show pointer location")
            Text("Press \(locator.key.title) twice to reveal the pointer.")
        }
        .featureSpot("clip-pointer-location")
        if locator.isOn {
            LabeledContent("Key") {
                HStack {
                    Picker("Key", selection: $locator.key) {
                        ForEach(PointerLocator.keys, id: \.rawValue) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .featureSpot("clip-pointer-location-key")
                    Button("Show Now") { locator.reveal() }
                }
            }
            .padding(.leading, 20)
        }
    }
}

/// The window under the pointer takes keyboard focus, without coming to the front.
private struct HoverFocusSection: View {
    @Bindable var hoverFocus: HoverFocus

    var body: some View {
        AccessibilityNotice(isNeeded: hoverFocus.isOn)
        Section("Windows") {
            Toggle(isOn: $hoverFocus.isOn) {
                Text("Focus the window under the pointer")
                Text("Type into a window just by pointing at it; it stays where it is. Hold a modifier key to move across windows without changing focus.")
            }
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
        Section {
            Toggle(isOn: $automation.followsAppearance) {
                Text("Switch pairs with light and dark appearance")
                Text("Applies a pair whenever macOS changes appearance, including on a schedule.")
            }
            .featureSpot("clip-follows-appearance")
            pairPicker("Light appearance", selection: $automation.lightPairID)
            pairPicker("Dark appearance", selection: $automation.darkPairID)
        } header: {
            Text("Appearance")
        }
    }

    private func pairPicker(_ title: LocalizedStringKey, selection: Binding<String>) -> some View {
        LabeledContent(title) {
            PairMenuButton(selection: Binding(get: { selection.wrappedValue }, set: { if let id = $0 { selection.wrappedValue = id } }),
                           pairs: pairs, accessibilityTitle: String(localized: "Pair for this appearance"), allowsNone: false)
        }
        .disabled(!automation.followsAppearance)
    }
}
