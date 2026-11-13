import SwiftUI

/// A setting that picks one of its options: side-by-side segments for up to four, a dropdown for
/// more, so every choice in Preferences looks the same and no call site picks a style itself.
///
/// Options are data, so their count can decide the look: a type's cases (label from a `String`
/// such as `\.title`), or any list of values with a label view each.
struct SettingsChoice<Value: Hashable, Label: View>: View {
    let title: Text
    let symbol: String?
    let caption: Text?
    @Binding var selection: Value
    let options: [Value]
    let style: SettingsChoiceStyle?
    let label: (Value) -> Label

    /// `style` overrides the look the option count would pick; leave it nil unless a row has a
    /// reason of its own (Laser › Open in keeps a menu for its app icons).
    init(title: Text, symbol: String?, caption: Text? = nil, selection: Binding<Value>, options: [Value],
         style: SettingsChoiceStyle? = nil, @ViewBuilder label: @escaping (Value) -> Label) {
        self.title = title
        self.symbol = symbol
        self.caption = caption
        _selection = selection
        self.options = options
        self.style = style
        self.label = label
    }

    init(_ title: LocalizedStringKey, symbol: String?, caption: LocalizedStringKey? = nil, selection: Binding<Value>,
         options: [Value], style: SettingsChoiceStyle? = nil, @ViewBuilder label: @escaping (Value) -> Label) {
        self.init(title: Text(title), symbol: symbol, caption: caption.map { Text($0) }, selection: selection,
                  options: options, style: style, label: label)
    }

    var body: some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            ChoicePicker(title: title, selection: $selection, options: options, style: style, label: label)
        }
    }
}

extension SettingsChoice where Value: CaseIterable, Label == Text {
    /// Every case of the type, each labelled by `label` (usually `\.title`).
    init(title: Text, symbol: String?, caption: Text? = nil, selection: Binding<Value>,
         label: @escaping (Value) -> String) {
        self.init(title: title, symbol: symbol, caption: caption, selection: selection,
                  options: Array(Value.allCases)) { Text(verbatim: label($0)) }
    }

    init(_ title: LocalizedStringKey, symbol: String?, caption: LocalizedStringKey? = nil, selection: Binding<Value>,
         label: @escaping (Value) -> String) {
        self.init(title: Text(title), symbol: symbol, caption: caption.map { Text($0) }, selection: selection, label: label)
    }
}
