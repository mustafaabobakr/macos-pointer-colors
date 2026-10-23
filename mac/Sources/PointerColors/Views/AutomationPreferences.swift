import SwiftUI

/// Preferences › Automation: appearance pairs, per-display sizes and shake to find.
struct AutomationPreferences: View {
    let model: AppModel
    @State private var shakeToFind = false

    var body: some View {
        Form {
            AppearanceSection(automation: model.automation, pairs: model.library.all)
            DisplaySection(automation: model.automation)
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

    private func pairPicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(pairs) { Text($0.name).tag($0.id) }
        }
        .disabled(!automation.followsAppearance)
    }
}

private struct DisplaySection: View {
    @Bindable var automation: Automation

    var body: some View {
        Section {
            Toggle(isOn: $automation.perDisplaySizes) {
                Text("Different pointer size on each display")
                Text("The size changes when the pointer moves onto another display.")
            }
            ForEach(automation.displays) { display in
                DisplaySizeRow(automation: automation, display: display)
            }
        } header: {
            Text("Displays")
        }
    }
}

private struct DisplaySizeRow: View {
    let automation: Automation
    let display: DisplayInfo

    var body: some View {
        LabeledContent(display.name) {
            HStack {
                Slider(value: Binding(get: { automation.size(for: display) },
                                      set: { automation.setSize($0, for: display) }),
                       in: SystemPointer.minimumScale...SystemPointer.maximumScale, step: 0.25)
                    .frame(width: 180)
                    .accessibilityLabel("Pointer size on \(display.name)")
                Text(String(format: "%.2f×", automation.size(for: display)))
                    .appFont(.caption, monospacedDigits: true)
                    .frame(width: 44, alignment: .trailing)
            }
        }
        .disabled(!automation.perDisplaySizes)
    }
}
