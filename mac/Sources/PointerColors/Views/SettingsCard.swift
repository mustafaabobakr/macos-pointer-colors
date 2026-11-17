import SwiftUI

/// A Preferences page: its title over a column of cards, scrolling as one.
struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    /// Shows a BETA badge beside the title.
    let isBeta: Bool
    @ViewBuilder var content: Content
    @Environment(\.appTextScale) private var scale

    init(_ title: LocalizedStringKey, isBeta: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isBeta = isBeta
        self.content = content()
    }

    var body: some View {
        ScrollView {
            SettingsStack(spacing: 20 * scale) {
                HStack(spacing: 10 * scale) {
                    Text(title)
                        .appFont(.title2, weight: .bold)
                        .accessibilityAddTraits(.isHeader)
                    if isBeta { BetaBadge() }
                }
                content
            }
            .frame(maxWidth: SettingsLayout.pageMaxWidth * scale)
            .frame(maxWidth: .infinity)
            .padding(SettingsLayout.pagePadding * scale)
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
        SettingsStack(spacing: 13 * scale) {
            if let title {
                Text(title)
                    .appFont(.body, weight: .semibold)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SettingsLayout.cardPadding * scale)
        .background { CardBackground(shape: shape) }
        // Nothing shows past the card's edge while it grows or shrinks.
        .clipShape(shape)
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
    @Environment(\.settingsReset) private var reset

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
        HStack(spacing: SettingsLayout.rowSpacing * scale) {
            if let symbol { SettingIcon(symbol: symbol) }
            VStack(alignment: .leading, spacing: 2 * scale) {
                HStack(spacing: 5 * scale) {
                    title
                    if let reset, reset.isChanged { SettingsResetButton(reset: reset, title: title) }
                }
                .animation(.easeOut(duration: 0.15), value: reset?.isChanged)
                if let caption {
                    caption
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Never squeezed by a wide control: below this the title would break mid-word.
            .frame(minWidth: SettingsLayout.titleMinWidth * scale, alignment: .leading)
            Spacer(minLength: SettingsLayout.rowSpacing * scale)
            // A row inside the control isn't this setting: it gets no reset of its own.
            accessory.environment(\.settingsReset, nil)
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

/// A setting's symbol in a small accent-tinted tile, in front of its row.
struct SettingIcon: View {
    let symbol: String
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 12 * scale, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: SettingsLayout.iconSide * scale, height: SettingsLayout.iconSide * scale)
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
