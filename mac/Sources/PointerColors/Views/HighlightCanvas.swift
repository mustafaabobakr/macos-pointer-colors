import SwiftUI

/// One display's share of the highlight overlay. Animates only while something is fading.
struct HighlightCanvas: View {
    let scene: HighlightScene
    /// The display's frame in global screen coordinates (origin bottom left).
    let screenFrame: CGRect

    var body: some View {
        let snapshot = HighlightSnapshot(scene: scene, screenFrame: screenFrame)
        TimelineView(.animation(paused: !scene.isAnimating)) { timeline in
            Canvas { context, _ in
                snapshot.draw(in: &context, now: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .ignoresSafeArea()
    }
}

/// A copy of the scene for one frame, with points moved into the display's own coordinates.
private struct HighlightSnapshot {
    let style: HighlightStyle
    let pointer: CGPoint
    let pulses: [Pulse]
    let laserDot: LaserDot?
    let strokes: [LaserStroke]

    @MainActor
    init(scene: HighlightScene, screenFrame: CGRect) {
        _ = scene.revision
        let local = { (p: CGPoint) in CGPoint(x: p.x - screenFrame.minX, y: screenFrame.maxY - p.y) }
        style = scene.style
        pointer = local(scene.pointer)
        pulses = scene.pulses.map { Pulse(point: local($0.point), start: $0.start) }
        laserDot = scene.laserDot.map { LaserDot(point: local($0.point), updatedAt: $0.updatedAt) }
        strokes = scene.strokes.map { LaserStroke(points: $0.points.map(local), finishedAt: $0.finishedAt) }
    }

    func draw(in context: inout GraphicsContext, now: TimeInterval) {
        if style.showsRing { drawRing(in: &context) }
        strokes.forEach { drawStroke($0, now: now, in: &context) }
        pulses.forEach { drawPulse($0, now: now, in: &context) }
        if let laserDot { drawDot(laserDot, now: now, in: &context) }
    }

    /// The pointer-sized circle the ring and pulse are built on.
    private var baseDiameter: Double { 44 * style.pointerScale }

    private func drawRing(in context: inout GraphicsContext) {
        let circle = Path(ellipseIn: square(at: pointer, side: baseDiameter))
        context.fill(circle, with: .color(style.ringColor.color.opacity(0.18)))
        context.stroke(circle, with: .color(style.ringColor.color.opacity(0.9)), lineWidth: 3)
    }

    /// Starts small and bright, then grows and fades.
    private func drawPulse(_ pulse: Pulse, now: TimeInterval, in context: inout GraphicsContext) {
        let progress = fraction(now - pulse.start, of: style.pulseDuration)
        guard progress < 1 else { return }
        let eased = 1 - (1 - progress) * (1 - progress)
        let side = baseDiameter * style.pulseSize * (0.6 + 1.2 * eased)
        let circle = Path(ellipseIn: square(at: pulse.point, side: side))
        context.stroke(circle, with: .color(style.pulseColor.color.opacity(0.95 * (1 - eased))), lineWidth: 4)
    }

    /// A soft glow, then the core, middle and center, fading once the pointer stops.
    private func drawDot(_ dot: LaserDot, now: TimeInterval, in context: inout GraphicsContext) {
        let alpha = 1 - fraction(now - dot.updatedAt, of: LaserDot.fade)
        guard alpha > 0 else { return }
        let layers: [(RGBA, Double, Double)] = [(style.laser.glow, 32, 0.18), (style.laser.glow, 16, 1),
                                                (style.laser.middle, 13, 1), (style.laser.center, 11, 1)]
        for (color, side, opacity) in layers {
            let circle = Path(ellipseIn: square(at: dot.point, side: side * style.laserSize))
            context.fill(circle, with: .color(color.color.opacity(opacity * alpha)))
        }
    }

    /// The same layers as the dot, as a line along the drag.
    private func drawStroke(_ stroke: LaserStroke, now: TimeInterval, in context: inout GraphicsContext) {
        let alpha = stroke.finishedAt.map { 1 - fraction(now - $0, of: style.trailFade) } ?? 0.95
        guard alpha > 0, stroke.points.count > 1 else { return }
        var path = Path()
        path.addLines(stroke.points)
        let layers: [(RGBA, Double, Double)] = [(style.laser.glow, 14, 0.2), (style.laser.glow, 6, 1),
                                                (style.laser.middle, 4, 1), (style.laser.center, 2, 1)]
        for (color, width, opacity) in layers {
            context.stroke(path, with: .color(color.color.opacity(opacity * alpha)),
                           style: StrokeStyle(lineWidth: width * style.laserSize, lineCap: .round, lineJoin: .round))
        }
    }

    private func square(at center: CGPoint, side: Double) -> CGRect {
        CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
    }

    /// How far `elapsed` is through `duration`, from 0 to 1.
    private func fraction(_ elapsed: TimeInterval, of duration: TimeInterval) -> Double {
        min(max(elapsed / max(duration, 0.01), 0), 1)
    }
}
