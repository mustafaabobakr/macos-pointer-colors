import SwiftUI

/// Ring, Ripple, Frost and Bokeh as cards side by side, each playing its pulse at real size while the
/// pointer is over it. The chosen one is outlined. A card whose style has settings changed from
/// their defaults shows a reset button in its picture's corner.
struct PulseStylePicker: View {
    @Binding var selection: PulseStyle
    /// The settings each card's reset button puts back.
    let highlight: PointerHighlight
    /// The pulse settings as drawn on screen; each card swaps in its own style.
    let style: HighlightStyle
    let pair: PointerPair
    @Environment(\.appTextScale) private var scale
    @AppStorage(PreviewBackdrop.key) private var backdrop = PreviewBackdrop.dark

    var body: some View {
        HStack(alignment: .top, spacing: 10 * scale) {
            ForEach(PulseStyle.allCases) { option in
                PulseStyleCard(option: option, style: style(for: option), pair: pair, pictureHeight: pictureHeight,
                               isSelected: selection == option, isChanged: highlight.isChanged(option),
                               reset: { highlight.reset(option) }) { selection = option }
            }
        }
        .environment(\.previewBackdrop, backdrop)
    }

    private func style(for option: PulseStyle) -> HighlightStyle {
        var shown = style
        shown.pulseStyle = option
        shown.showsRing = false
        return shown
    }

    /// One fixed height, so the cards keep their size as the settings change. A pulse larger than
    /// it is cut off at the edges rather than shrunk, so it stays at its real size.
    private var pictureHeight: CGFloat { Self.pictureHeight * scale }

    private static let pictureHeight: CGFloat = 160
}

private struct PulseStyleCard: View {
    let option: PulseStyle
    let style: HighlightStyle
    let pair: PointerPair
    let pictureHeight: CGFloat
    let isSelected: Bool
    /// Whether this style's own settings differ from their defaults, and how to put them back.
    let isChanged: Bool
    let reset: () -> Void
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
        // Over the picture's corner but outside the card's button, so it takes its own clicks.
        .overlay(alignment: .topLeading) { PreviewBackdropPicker().padding(8 * scale) }
        .overlay(alignment: .topTrailing) {
            if isChanged { StyleResetButton(title: option.title, reset: reset).padding(14 * scale) }
        }
        .animation(.easeOut(duration: 0.15), value: isChanged)
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

/// The reset button in a style card's corner: puts that style's own settings back to their defaults.
private struct StyleResetButton: View {
    let title: String
    let reset: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: reset) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 16 * scale))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.black.opacity(0.45))
        }
        .buttonStyle(.plain)
        .help(Text("Reset \(title)'s settings to their defaults"))
        .accessibilityLabel(Text("Reset \(title)'s settings to their defaults"))
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }
}
