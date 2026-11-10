import SwiftUI

/// A wide still picture of one highlight at the top of its Preferences page, drawn by the
/// overlay's own code with the settings below it, so it changes as they do. Dimmed while the
/// highlight is off.
struct HighlightPreviewBanner: View {
    let scene: HighlightPreviewScene
    let pair: PointerPair
    let sample: HighlightPreviewSample
    let isOn: Bool
    @Environment(\.appTextScale) private var scale

    /// The picture's height; its width fills the card.
    private static let height: CGFloat = 170
    /// The height the pictures are laid out at, as in the menu's cards.
    private static let layoutHeight: CGFloat = 88

    var body: some View {
        let height = max(Self.height * scale, sample.realSize ? realHeight : 0)
        HighlightPreviewImage(scene: scene, pair: pair, sample: sample, zoom: sample.realSize ? 1 : height / Self.layoutHeight)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
            .opacity(isOn ? 1 : 0.45)
            .accessibilityHidden(true)
    }

    /// At real size, tall enough for the widest ring or pulse, which can outgrow the usual picture.
    private var realHeight: CGFloat {
        let style = sample.style
        switch scene {
        case .ring: return 44 * style.pointerScale * style.ringSize + style.ringLineWidth + 16
        case .pulse: return style.pulseRadius * 2 + 16
        case .laser, .press: return 0
        }
    }
}
