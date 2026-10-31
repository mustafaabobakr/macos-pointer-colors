import SwiftUI

/// A Preferences page: its title over a column of cards, scrolling as one.
struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content
    @Environment(\.appTextScale) private var scale

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20 * scale) {
                Text(title)
                    .appFont(.title2, weight: .bold)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: 760 * scale)
            .frame(maxWidth: .infinity)
            .padding(22 * scale)
        }
    }
}

/// One rounded group of related settings, with an optional heading inside it. `anchor` names
/// it for search, which scrolls to it and outlines it for a moment.
struct SettingsCard<Content: View>: View {
    let title: LocalizedStringKey?
    let anchor: String?
    @ViewBuilder var content: Content
    @Environment(\.appTextScale) private var scale
    @Environment(\.settingsFocus) private var focus

    init(_ title: LocalizedStringKey? = nil, anchor: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.anchor = anchor
        self.content = content()
    }

    private var isFocused: Bool { anchor != nil && focus == anchor }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
        VStack(alignment: .leading, spacing: 13 * scale) {
            if let title {
                Text(title)
                    .appFont(.body, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16 * scale)
        .background { CardBackground(shape: shape) }
        .overlay { shape.strokeBorder(Color.accentColor, lineWidth: 2).opacity(isFocused ? 1 : 0) }
        .animation(.easeOut(duration: 0.3), value: isFocused)
        .id(anchor)
    }
}

/// The card's fill: Liquid Glass on macOS 26 and later, a light wash before it or with Reduce
/// Transparency on.
private struct CardBackground: View {
    let shape: RoundedRectangle
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if #available(macOS 26, *), !reduceTransparency {
            Color.clear.glassEffect(.regular, in: shape)
        } else {
            shape.fill(.quaternary.opacity(0.35))
        }
    }
}

/// A setting: its icon, title and one line of explanation, with its control on the right.
struct SettingsRow<Accessory: View>: View {
    let symbol: String?
    let title: Text
    let caption: Text?
    @ViewBuilder var accessory: Accessory
    @Environment(\.appTextScale) private var scale

    init(_ title: LocalizedStringKey, symbol: String?, caption: LocalizedStringKey? = nil,
         @ViewBuilder accessory: () -> Accessory) {
        self.init(symbol: symbol, title: Text(title), caption: caption.map { Text($0) }, accessory: accessory)
    }

    init(symbol: String?, title: Text, caption: Text? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.symbol = symbol
        self.title = title
        self.caption = caption
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: 12 * scale) {
            if let symbol { SettingIcon(symbol: symbol) }
            VStack(alignment: .leading, spacing: 2 * scale) {
                title
                if let caption {
                    caption
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12 * scale)
            accessory
        }
        .accessibilityElement(children: .contain)
    }
}

extension SettingsRow where Accessory == EmptyView {
    /// A row with no control of its own, heading the controls under it.
    init(_ title: LocalizedStringKey, symbol: String?, caption: LocalizedStringKey? = nil) {
        self.init(title, symbol: symbol, caption: caption) { EmptyView() }
    }
}

/// A switch row: the most common setting.
struct SettingsToggle: View {
    let title: Text
    let symbol: String?
    let caption: Text?
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, symbol: String?, caption: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.init(title: Text(title), symbol: symbol, caption: caption.map { Text($0) }, isOn: isOn)
    }

    init(title: Text, symbol: String?, caption: Text? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.symbol = symbol
        self.caption = caption
        _isOn = isOn
    }

    var body: some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            Toggle(isOn: $isOn) { title }
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

/// A menu row: a picker shown as a pop-up button on the right.
struct SettingsMenu<Value: Hashable, Options: View>: View {
    let title: Text
    let symbol: String?
    let caption: Text?
    @Binding var selection: Value
    @ViewBuilder var options: Options

    init(_ title: LocalizedStringKey, symbol: String?, caption: LocalizedStringKey? = nil,
         selection: Binding<Value>, @ViewBuilder options: () -> Options) {
        self.init(title: Text(title), symbol: symbol, caption: caption.map { Text($0) }, selection: selection, options: options)
    }

    init(title: Text, symbol: String?, caption: Text? = nil, selection: Binding<Value>, @ViewBuilder options: () -> Options) {
        self.title = title
        self.symbol = symbol
        self.caption = caption
        _selection = selection
        self.options = options()
    }

    var body: some View {
        SettingsRow(symbol: symbol, title: title, caption: caption) {
            Picker(selection: $selection) { options } label: { title }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
        }
    }
}

/// A setting's symbol in a small accent-tinted tile, in front of its row.
struct SettingIcon: View {
    let symbol: String
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12 * scale, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 26 * scale, height: 26 * scale)
            .background(Color.accentColor.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 7 * scale, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Where a row's text starts, past its icon, so follow-up controls can line up with it.
@MainActor func settingsRowTextInset(_ scale: CGFloat) -> CGFloat { (26 + 12) * scale }

private struct SettingsFocusKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// The card search just jumped to, outlined for a moment.
    var settingsFocus: String? {
        get { self[SettingsFocusKey.self] }
        set { self[SettingsFocusKey.self] = newValue }
    }
}
