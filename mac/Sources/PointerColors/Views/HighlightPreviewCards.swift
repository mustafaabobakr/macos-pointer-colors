import SwiftUI

/// Still pictures of the pulse and the laser with the current colors and settings, drawn by the
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
                HighlightPreviewImage(kind: effect, style: style, pair: pair)
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

/// One frozen frame: three pulses fading at different stages, or a laser trail with its dot.
private struct HighlightPreviewImage: View {
    let kind: HighlightEffect
    let style: HighlightStyle
    let pair: PointerPair

    /// A fixed moment the sample scene is drawn at.
    private static let now: TimeInterval = 1_000

    var body: some View {
        GeometryReader { proxy in
            let scene = sampleScene(in: proxy.size)
            ZStack(alignment: .topLeading) {
                Color(white: 0.12)
                Canvas { context, _ in
                    HighlightSnapshot(scene: scene, toLocal: { $0 }).draw(in: &context, now: Self.now)
                }
                PointerGlyph(pair: pair)
                    .frame(width: 14)
                    .offset(x: scene.pointer.x - 1, y: scene.pointer.y - 1)
            }
        }
    }

    private func sampleScene(in size: CGSize) -> HighlightScene {
        let scene = HighlightScene()
        scene.style = style
        // Normal pointer size, so the pulses fit the card.
        scene.style.pointerScale = 1
        if kind == .pulse { addPulses(to: scene, in: size) } else { addLaser(to: scene, in: size) }
        return scene
    }

    private func addPulses(to scene: HighlightScene, in size: CGSize) {
        let spots = [(0.22, 0.6, 0.7), (0.5, 0.35, 0.4), (0.78, 0.6, 0.12)]
        scene.pulses = spots.map { x, y, age in
            Pulse(point: CGPoint(x: size.width * x, y: size.height * y), start: Self.now - age * style.pulseDuration)
        }
        scene.pointer = scene.pulses.last?.point ?? .zero
        // The pointer is mid long press, so the held ring shows next to the click pulses.
        if style.showsHold { scene.hold = Hold(point: scene.pointer, start: Self.now - Hold.threshold - 1) }
    }

    private func addLaser(to scene: HighlightScene, in size: CGSize) {
        let points = stride(from: 0.12, through: 0.8, by: 0.02).map { t in
            CGPoint(x: size.width * t, y: size.height * (0.5 + 0.28 * sin(t * 2 * .pi * 1.3)))
        }
        scene.strokes = [LaserStroke(points: points)]
        let end = points.last ?? .zero
        scene.laserDot = LaserDot(point: end, updatedAt: Self.now)
        scene.pointer = end
    }
}
