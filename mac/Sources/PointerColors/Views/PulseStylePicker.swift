import SwiftUI

/// Ring, Ripple and Frost as cards side by side, each playing its pulse at real size while the
/// pointer is over it. The chosen one is outlined.
struct PulseStylePicker: View {
    @Binding var selection: PulseStyle
    /// The pulse settings as drawn on screen; each card swaps in its own style.
    let style: HighlightStyle
    let pair: PointerPair
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(alignment: .top, spacing: 10 * scale) {
            ForEach(PulseStyle.allCases) { option in
                PulseStyleCard(option: option, style: style(for: option), pair: pair, pictureHeight: pictureHeight,
                               isSelected: selection == option) { selection = option }
            }
        }
    }

    private func style(for option: PulseStyle) -> HighlightStyle {
        var shown = style
        shown.pulseStyle = option
        shown.showsRing = false
        return shown
    }

    /// Tall enough for the widest of the three, so all the cards line up.
    private var pictureHeight: CGFloat {
        PulseStyle.allCases.map { style(for: $0).pulseRadius * 2 + 16 }.max() ?? 0
    }
}

private struct PulseStyleCard: View {
    let option: PulseStyle
    let style: HighlightStyle
    let pair: PointerPair
    let pictureHeight: CGFloat
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8 * scale) {
                PulseStyleDemo(style: style, pair: pair)
                    .frame(height: pictureHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
                title
                Text(option.summary).appFont(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var title: some View {
        HStack(spacing: 4 * scale) {
            Text(option.title)
                .appFont(.callout, weight: .semibold)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
            if option == .ring {
                Text("Default").appFont(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
