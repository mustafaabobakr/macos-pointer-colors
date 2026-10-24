import SwiftUI

/// Still pictures of the pulse and the laser with the current colors and settings, drawn by the
/// same code as the real overlay. The selected one is outlined.
struct HighlightPreviewCards: View {
    let mode: HighlightMode
    let style: HighlightStyle
    let pair: PointerPair

    var body: some View {
        HStack(spacing: 10) {
            card(.pulse)
            card(.laser)
        }
    }

    private func card(_ kind: HighlightMode) -> some View {
        VStack(spacing: 4) {
            HighlightPreviewImage(kind: kind, style: style, pair: pair)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(kind == mode ? Color.accentColor : .clear, lineWidth: 2)
                }
            Text(kind.title).appFont(.caption).foregroundStyle(kind == mode ? .primary : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title) preview")
    }
}

/// One frozen frame: three pulses fading at different stages, or a laser trail with its dot.
private struct HighlightPreviewImage: View {
    let kind: HighlightMode
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
