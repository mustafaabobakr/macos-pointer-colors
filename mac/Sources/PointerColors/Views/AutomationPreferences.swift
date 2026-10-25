import SwiftUI

/// Preferences › Automation: appearance pairs and shake to find. Per-display sizes live in the menu.
struct AutomationPreferences: View {
    let model: AppModel
    @State private var shakeToFind = false

    var body: some View {
        Form {
            AppearanceSection(automation: model.automation, pairs: model.library.all)
            AppColorsSection(automation: model.automation, pairs: model.library.all)
            Section("Finding the pointer") {
                Toggle(isOn: Binding(get: { shakeToFind }, set: { shakeToFind = $0; model.setShakeToFind($0) })) {
                    Text("Shake mouse pointer to locate")
                    Text("Move the pointer back and forth quickly to make it bigger for a moment.")
                }
                .disabled(model.shakeToFind == nil)
            }
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

private struct AppearanceSection: View {
    @Bindable var automation: Automation
    let pairs: [PointerPair]

    var body: some View {
        Section {
            Toggle(isOn: $automation.followsAppearance) {
                Text("Switch pairs with light and dark appearance")
                Text("Applies a pair whenever macOS changes appearance, including on a schedule.")
            }
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
