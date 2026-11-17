import SwiftUI

/// Bokeh's four shapes as cards, two by two so each is wide and tall enough to show its whole
/// shape at real size, each playing a click of its shape while the pointer is over it. Checked cards are the shapes Bokeh's clicks use; one always stays checked.
struct BokehShapePicker: View {
    @Bindable var highlight: PointerHighlight
    /// The pulse as drawn on screen; each card swaps in its own shape.
    let style: HighlightStyle
    let pair: PointerPair
    @Environment(\.appTextScale) private var scale
    @AppStorage(PreviewBackdrop.key) private var backdrop = PreviewBackdrop.dark

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10 * scale), GridItem(.flexible())], spacing: 10 * scale) {
            ForEach(BokehShape.allCases) { shape in
                BokehShapeCard(shape: shape, style: style(for: shape), pair: pair,
                               isChecked: highlight.bokehCustomShapes.contains(shape)) {
                    highlight.toggleBokehShape(shape)
                }
            }
        }
        .environment(\.previewBackdrop, backdrop)
    }

    private func style(for shape: BokehShape) -> HighlightStyle {
        var shown = style
        shown.pulseStyle = .bokeh
        shown.showsRing = false
        shown.bokehShapes = [shape]
        return shown
    }
}

private struct BokehShapeCard: View {
    let shape: BokehShape
    let style: HighlightStyle
    let pair: PointerPair
    let isChecked: Bool
    let toggle: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 8 * scale) {
                PulseStyleDemo(style: style, pair: pair)
                    .frame(height: 220 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
                HStack(spacing: 4 * scale) {
                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                    Text(shape.title)
                        .appFont(.callout, weight: .semibold)
                        .foregroundStyle(isChecked ? Color.accentColor : .primary)
                }
                Text(shape.summary).appFont(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale)
                    .strokeBorder(isChecked ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isChecked ? 2.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}
