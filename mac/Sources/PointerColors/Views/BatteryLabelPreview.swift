import SwiftUI

/// The pointer with its battery label beside it, both at the size they're drawn on screen, so
/// the chosen side shows as it will. Dimmed while the label is off.
struct BatteryLabelPreview: View {
    let position: BatteryLabelPosition
    let level: Int
    let charging: Bool
    let redLevel: Int
    let pair: PointerPair
    let pointerScale: Double
    let isOn: Bool
    @Environment(\.appTextScale) private var scale

    var body: some View {
        let width = 14 * pointerScale
        PointerTipLayout(position: position, pointerTip: CGPoint(x: width / 8, y: width / 12)) {
            PointerGlyph(pair: pair).frame(width: width)
            BatteryLabelView(level: level, charging: charging, redLevel: redLevel)
        }
        // Right and left are the screen's, also in a right-to-left language.
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
        .frame(height: max(120 * scale, width * 1.25 * 2 + 40))
        .background(Color(white: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        .opacity(isOn ? 1 : 0.45)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of the battery label: \(position.title)"))
    }
}

/// Puts the pointer's tip in the middle, and the label where the real one goes from that tip.
private struct PointerTipLayout: Layout {
    let position: BatteryLabelPosition
    /// Where the tip is inside the pointer's picture, from its top left.
    let pointerTip: CGPoint

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let tip = CGPoint(x: bounds.midX, y: bounds.midY)
        subviews[0].place(at: CGPoint(x: tip.x - pointerTip.x, y: tip.y - pointerTip.y), anchor: .topLeading,
                          proposal: .unspecified)
        let label = subviews[1].sizeThatFits(.unspecified)
        let offset = position.offset(for: label)
        subviews[1].place(at: CGPoint(x: tip.x + offset.x, y: tip.y + offset.y), anchor: .topLeading, proposal: .unspecified)
    }
}
