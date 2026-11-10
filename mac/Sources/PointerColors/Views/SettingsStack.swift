import SwiftUI

/// A column of rows, like a leading-aligned VStack, except that the gap before a `Reveal` is never
/// taller than the Reveal. Closed to nothing it then leaves no gap of its own, and as it opens its
/// gap opens with it, so the rows below move down in one smooth motion. Other rows, dividers
/// included, keep the full gap.
struct SettingsStack: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width
        let sizes = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
        let gaps = subviews.indices.dropFirst().map { gap(before: subviews[$0], height: sizes[$0].height) }
        let height = sizes.map(\.height).reduce(0, +) + gaps.reduce(0, +)
        return CGSize(width: width ?? sizes.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for (index, subview) in subviews.enumerated() {
            let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            if index > 0 { y += gap(before: subview, height: height) }
            subview.place(at: CGPoint(x: bounds.minX, y: y), anchor: .topLeading,
                          proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height
        }
    }

    /// The full spacing, or before a Reveal shorter than it, as much as the Reveal is tall.
    private func gap(before subview: LayoutSubview, height: CGFloat) -> CGFloat {
        subview[RevealRow.self] ? min(spacing, max(height, 0)) : spacing
    }
}

/// Marks a `Reveal` for `SettingsStack`, whose gap before it grows with it.
struct RevealRow: LayoutValueKey {
    static let defaultValue = false
}
