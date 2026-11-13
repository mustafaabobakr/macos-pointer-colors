import SwiftUI

/// A picker for one of `options` that picks its own look from how many there are (see
/// `SettingsChoiceStyle`). `SettingsChoice` puts it in a settings row; use it alone only when the
/// row holds more than the picker.
struct ChoicePicker<Value: Hashable, Label: View>: View {
    let title: Text
    @Binding var selection: Value
    let options: [Value]
    /// Overrides the look the option count would pick; nil lets the count decide.
    var style: SettingsChoiceStyle?
    @ViewBuilder let label: (Value) -> Label

    var body: some View {
        styled(Picker(selection: $selection) {
            ForEach(options, id: \.self) { label($0).tag($0) }
        } label: {
            title
        })
        .labelsHidden()
        .fixedSize()
    }

    @ViewBuilder private func styled(_ picker: some View) -> some View {
        switch style ?? SettingsChoiceStyle(optionCount: options.count) {
        case .segmented: picker.pickerStyle(.segmented)
        case .menu: picker.pickerStyle(.menu)
        }
    }
}
