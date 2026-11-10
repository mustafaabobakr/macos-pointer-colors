import SwiftUI

/// One frozen frame, drawn by the same code as the real overlay: three pulses fading at different
/// stages, a laser trail with its dot, the ring around a still pointer, or a pointer shrunk inside
/// the outline of its own size.
struct HighlightPreviewImage: View {
    let scene: HighlightPreviewScene
    let pair: PointerPair
    let sample: HighlightPreviewSample
    /// Draws everything this many times larger than the overlay would, for a big picture.
    var zoom: CGFloat = 1

    /// A fixed moment the sample scene is drawn at.
    private static let now: TimeInterval = 1_000

    private var style: HighlightStyle { sample.style }

    var body: some View {
        if scene == .press { pressImage } else { sceneImage }
    }

    /// Before and after: the pointer at full size, an arrow, then the pointer pressed, with click
    /// marks at its tip and a dashed outline of the size it shrank from.
    private var pressImage: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.height * 0.42, 28 * zoom)
            HStack(alignment: .top, spacing: width * 0.45) {
                PointerGlyph(pair: pair).frame(width: width)
                Image(systemName: "arrow.right")
                    .font(.system(size: width * 0.4, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, width * 0.45)
                pressedPointer(width: width)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color(white: 0.12))
        }
    }

    private var shownPressScale: Double {
        sample.exactPress ? sample.pressScale : min(sample.pressScale, 0.7)
    }

    private func pressedPointer(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            PointerShape()
                .stroke(pair.outline.color.opacity(0.6), style: .init(lineWidth: 1, lineJoin: .round, dash: [2.5, 2]))
                .aspectRatio(24.0 / 30.0, contentMode: .fit)
                .frame(width: width)
            PointerGlyph(pair: pair).frame(width: width * shownPressScale)
        }
        .overlay(alignment: .topLeading) {
            ClickMarks()
                .stroke(.white.opacity(0.75), style: .init(lineWidth: 1.5, lineCap: .round))
                .frame(width: width * 0.4, height: width * 0.4)
                .offset(x: -width * 0.42, y: -width * 0.42)
        }
    }

    private var sceneImage: some View {
        GeometryReader { proxy in
            // Laid out at overlay size, then drawn scaled up, so it stays sharp.
            let scene = sampleScene(in: CGSize(width: proxy.size.width / zoom, height: proxy.size.height / zoom))
            ZStack(alignment: .topLeading) {
                Color(white: 0.12)
                Canvas { [zoom] context, _ in
                    context.scaleBy(x: zoom, y: zoom)
                    HighlightSnapshot(scene: scene, toLocal: { $0 }).draw(in: &context, now: Self.now)
                }
                PointerGlyph(pair: pair)
                    .frame(width: 14 * zoom)
                    .offset(x: (scene.pointer.x - 1) * zoom, y: (scene.pointer.y - 1) * zoom)
            }
        }
    }

    private func sampleScene(in size: CGSize) -> HighlightScene {
        let scene = HighlightScene()
        scene.style = style
        // Normal pointer size, so the pulses fit the card.
        scene.style.pointerScale = 1
        switch self.scene {
        case .pulse: addPulses(to: scene, in: size)
        case .laser: addLaser(to: scene, in: size)
        case .ring, .press: scene.pointer = CGPoint(x: size.width / 2, y: size.height / 2)
        }
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

    /// Widths as if the pointer started slowly, sped up through the middle and slowed to stop,
    /// so the GoodNotes look shows its thick and thin parts.
    private static func shares(along points: [CGPoint]) -> [Double] {
        var pace = LaserPace()
        var time = 0.0
        return points.indices.map { index in
            let progress = Double(index) / Double(max(points.count - 1, 1))
            time += 0.004 + 0.05 * pow(1 - sin(progress * .pi), 2)
            return pace.share(at: points[index], time: time)
        }
    }

    private func addLaser(to scene: HighlightScene, in size: CGSize) {
        let points = stride(from: 0.12, through: 0.8, by: 0.02).map { t in
            CGPoint(x: size.width * t, y: size.height * (0.5 + 0.28 * sin(t * 2 * .pi * 1.3)))
        }
        if sample.showsTrail { scene.strokes = [LaserStroke(points: points, shares: Self.shares(along: points))] }
        let end = points.last ?? .zero
        if sample.showsDot { scene.laserDot = LaserDot(point: end, updatedAt: Self.now) }
        scene.pointer = end
    }
}

/// Three short lines fanning out up and to the left of the bottom-right corner, where the tip is:
/// the mark of a click.
private struct ClickMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.maxX, y: rect.maxY)
        let reach = min(rect.width, rect.height)
        var path = Path()
        for degrees in [180.0, 225.0, 270.0] {
            let angle = degrees * .pi / 180
            path.move(to: CGPoint(x: tip.x + cos(angle) * reach * 0.35, y: tip.y + sin(angle) * reach * 0.35))
            path.addLine(to: CGPoint(x: tip.x + cos(angle) * reach, y: tip.y + sin(angle) * reach))
        }
        return path
    }
}
