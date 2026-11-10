import SwiftUI

/// Still pictures of the pulse, the laser and the press with the current colors and settings, drawn by the
/// same code as the real overlay. Each is also its switch: click to turn it on or off.
struct HighlightPreviewCards: View {
    let highlight: PointerHighlight
    let style: HighlightStyle
    let pair: PointerPair
    /// The pictures' height: shorter in the menu than in Preferences.
    var imageHeight: CGFloat = 96

    var body: some View {
        HStack(spacing: 10) {
            ForEach(HighlightEffect.allCases) { card($0) }
        }
    }

    private func card(_ effect: HighlightEffect) -> some View {
        let isOn = highlight.isOn(effect)
        return Button { highlight.setOn(!isOn, effect) } label: {
            VStack(spacing: 4) {
                HighlightPreviewImage(scene: HighlightPreviewScene(effect), pair: pair,
                                      sample: HighlightPreviewSample(style: style, pressScale: highlight.pressScale))
                    .frame(height: imageHeight)
                    .opacity(isOn ? 1 : 0.45)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isOn ? 2 : 1)
                    }
                    .overlay(alignment: .topTrailing) { badge(isOn) }
                Label(effect.title, systemImage: effect.systemImage)
                    .appFont(.caption, weight: isOn ? .semibold : .regular)
                    .foregroundStyle(isOn ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(effect.title)
        .accessibilityValue(isOn ? String(localized: "On") : String(localized: "Off"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .featureSpot("clip-card-\(effect.rawValue)")
    }

    /// A check when on, an empty circle when off, like a checkbox on the picture.
    private func badge(_ isOn: Bool) -> some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isOn ? Color.accentColor : .white.opacity(0.6))
            .background(Circle().fill(isOn ? .white : .clear).padding(2))
            .padding(6)
    }
}
