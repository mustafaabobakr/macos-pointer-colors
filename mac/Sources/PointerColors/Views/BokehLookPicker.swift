import SwiftUI

/// Bokeh's looks as cards, each showing the Bokeh card's picture painted in that look from the
/// pair's or the custom color, and playing it at real size while the pointer is over it.
struct BokehLookPicker: View {
    @Binding var selection: BokehColorLook
    /// The pair's or the custom color the looks are built from.
    let color: RGBA
    /// The pulse as drawn on screen; each card swaps in its own look.
    let style: HighlightStyle
    let pair: PointerPair
    @Environment(\.appTextScale) private var scale
    @AppStorage(PreviewBackdrop.key) private var backdrop = PreviewBackdrop.dark

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140 * scale), spacing: 10 * scale)], spacing: 10 * scale) {
            ForEach(BokehColorLook.allCases) { look in
                BokehLookCard(look: look, style: style(for: look), pair: pair, isSelected: selection == look) {
                    selection = look
                }
            }
        }
        .environment(\.previewBackdrop, backdrop)
    }

    private func style(for look: BokehColorLook) -> HighlightStyle {
        var shown = style
        shown.pulseStyle = .bokeh
        shown.showsRing = false
        shown.bokehPalette = look.palette(for: color)
        return shown
    }
}

private struct BokehLookCard: View {
    let look: BokehColorLook
    let style: HighlightStyle
    let pair: PointerPair
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6 * scale) {
                PulseStyleDemo(style: style, pair: pair)
                    .frame(height: 140 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
                Text(look.title)
                    .appFont(.callout, weight: .semibold)
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
            }
            .padding(7 * scale)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(look.summary)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
