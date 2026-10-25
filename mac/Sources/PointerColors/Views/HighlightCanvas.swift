import SwiftUI

/// Draws a highlight scene. Animates only while something is fading.
struct HighlightCanvas: View {
    let scene: HighlightScene
    /// Turns a scene point into this view's own coordinates (origin top left).
    let toLocal: (CGPoint) -> CGPoint

    /// One display's share of the overlay; the scene is in global screen coordinates.
    init(scene: HighlightScene, screenFrame: CGRect) {
        self.scene = scene
        toLocal = { CGPoint(x: $0.x - screenFrame.minX, y: screenFrame.maxY - $0.y) }
    }

    /// A scene already in this view's coordinates, like the demo pad in Preferences.
    init(scene: HighlightScene) {
        self.scene = scene
        toLocal = { $0 }
    }

    var body: some View {
        let snapshot = HighlightSnapshot(scene: scene, toLocal: toLocal)
        TimelineView(.animation(paused: !scene.isAnimating)) { timeline in
            Canvas { context, _ in
                snapshot.draw(in: &context, now: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .ignoresSafeArea()
    }
}

/// A copy of the scene for one frame, with points moved into the view's own coordinates.
struct HighlightSnapshot {
    let style: HighlightStyle
    let pointer: CGPoint
    let pulses: [Pulse]
    let hold: Hold?
    let laserDot: LaserDot?
    let strokes: [LaserStroke]

    @MainActor
    init(scene: HighlightScene, toLocal local: (CGPoint) -> CGPoint) {
        _ = scene.revision
        style = scene.style
        pointer = local(scene.pointer)
        pulses = scene.pulses.map { Pulse(point: local($0.point), start: $0.start) }
        hold = scene.hold.map { Hold(point: local($0.point), start: $0.start, releasedAt: $0.releasedAt) }
        laserDot = scene.laserDot.map { LaserDot(point: local($0.point), updatedAt: $0.updatedAt) }
        strokes = scene.strokes.map { LaserStroke(points: $0.points.map(local), finishedAt: $0.finishedAt) }
    }

    func draw(in context: inout GraphicsContext, now: TimeInterval) {
        if style.showsRing { drawRing(in: &context) }
        strokes.forEach { drawStroke($0, now: now, in: &context) }
        pulses.forEach { drawPulse($0, now: now, in: &context) }
        if let hold { drawHold(hold, now: now, in: &context) }
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
        let elapsed = now - pulse.start
        guard elapsed < style.pulseDuration else { return }
        switch style.pulseStyle {
        case .ring: drawPulseRing(at: pulse.point, progress: fraction(elapsed, of: style.pulseDuration), in: &context)
        case .ripple: drawRipple(at: pulse.point, elapsed: elapsed, in: &context)
        }
    }

    /// One ring that grows and fades.
    private func drawPulseRing(at point: CGPoint, progress: Double, in context: inout GraphicsContext) {
        let eased = 1 - (1 - progress) * (1 - progress)
        let side = baseDiameter * style.pulseSize * (0.6 + 1.2 * eased)
        let circle = Path(ellipseIn: square(at: point, side: side))
        context.stroke(circle, with: .color(style.pulseColor.color.opacity(0.95 * (1 - eased))), lineWidth: 4)
    }

    /// Three waves, each leaving a little after the one before, spreading wider and thinner than
    /// the ring as they fade, like a ripple on water. All three finish within the pulse length.
    private func drawRipple(at point: CGPoint, elapsed: TimeInterval, in context: inout GraphicsContext) {
        let wave = style.pulseDuration * 0.7
        let gap = style.pulseDuration * 0.15
        for index in 0..<3 {
            let progress = fraction(elapsed - Double(index) * gap, of: wave)
            guard progress > 0, progress < 1 else { continue }
            let eased = 1 - (1 - progress) * (1 - progress)
            let side = baseDiameter * style.pulseSize * (0.3 + 1.9 * eased)
            let circle = Path(ellipseIn: square(at: point, side: side))
            let opacity = 0.9 * (1 - progress) * (1 - progress)
            context.stroke(circle, with: .color(style.pulseColor.color.opacity(opacity)), lineWidth: 3 - 2 * eased)
        }
    }

    /// After a long press: a small filled ring grows in under the pointer and breathes while held,
    /// then fades on release while a click pulse goes out from it.
    private func drawHold(_ hold: Hold, now: TimeInterval, in context: inout GraphicsContext) {
        let shown = fraction(now - hold.start - Hold.threshold, of: Hold.grow)
        guard shown > 0 else { return }
        let gone = hold.releasedAt.map { fraction(now - $0, of: Hold.release) } ?? 0
        let breathe = hold.releasedAt == nil ? 0.04 * sin((now - hold.start) * 2 * .pi / 1.2) : 0
        let scale = (0.6 + 0.4 * shown + breathe) * Hold.size
        let opacity = shown * (1 - gone)
        let circle = Path(ellipseIn: square(at: hold.point, side: baseDiameter * style.pulseSize * scale))
        context.fill(circle, with: .color(style.pulseColor.color.opacity(0.35 * opacity)))
        context.stroke(circle, with: .color(style.pulseColor.color.opacity(0.95 * opacity)), lineWidth: 3)
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
