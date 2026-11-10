import SwiftUI

/// Rows that show only while another setting allows them. Showing them opens a space that grows
/// from nothing to their full height, pushing what's below down and growing the card with it,
/// while they fade in from the top; hiding them closes it again. Nothing is drawn outside that
/// space, so no row shows past the card's edge on the way. In a `SettingsStack` (every card and
/// page), the gap before it opens and closes with it. Animated when the change is, as by a
/// `revealing()` binding, and a Reveal inside another one moves with it.
struct Reveal<Content: View>: View {
    let isShown: Bool
    /// The gap between its own rows, before Text size: 13, as in a card.
    var spacing: CGFloat = 13
    @ViewBuilder var content: Content
    @Environment(\.appTextScale) private var scale

    var body: some View {
        RevealLayout(shown: isShown ? 1 : 0) {
            SettingsStack(spacing: spacing * scale) { content }
        }
        .clipped()
        .opacity(isShown ? 1 : 0)
        .allowsHitTesting(isShown)
        .accessibilityHidden(!isShown)
        .disabled(!isShown)
        .layoutValue(key: RevealRow.self, value: true)
    }
}

/// Shows `shown` of its content's height, from the top: 0 for none, 1 for all of it. The share is
/// what animates, and the content's height is asked for on every frame, so when the content itself
/// is growing or shrinking, as with a Reveal inside, the space follows it exactly.
private struct RevealLayout: Layout {
    var shown: CGFloat

    var animatableData: CGFloat {
        get { shown }
        set { shown = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? size.width, height: size.height * max(shown, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading,
                              proposal: ProposedViewSize(width: bounds.width, height: nil))
    }
}
