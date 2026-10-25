import SwiftUI

/// Draws a highlight scene. Animates only while something on it is fading.
///
/// Each display has one of these covering it. A display only keeps what is near it, so the others
/// get an empty picture that never changes and are not redrawn at all, and drawing happens off the
/// main thread, so a busy frame never holds up mouse events.
struct HighlightCanvas: View {
    let scene: HighlightScene
    /// Turns a scene point into this view's own coordinates (origin top left).
    let toLocal: (CGPoint) -> CGPoint
    /// This view's area in its own coordinates, to drop what's far outside it. Nil keeps all.
    let bounds: CGRect?

    /// One display's share of the overlay; the scene is in global screen coordinates.
    init(scene: HighlightScene, screenFrame: CGRect) {
        self.scene = scene
        toLocal = { CGPoint(x: $0.x - screenFrame.minX, y: screenFrame.maxY - $0.y) }
        bounds = CGRect(origin: .zero, size: screenFrame.size)
    }

    /// A scene already in this view's coordinates, like the demo pad in Preferences.
    init(scene: HighlightScene) {
        self.scene = scene
        toLocal = { $0 }
        bounds = nil
    }

    var body: some View {
        // On a display the pulses are Core Animation layers above this (PulseLayerView).
        let snapshot = HighlightSnapshot(scene: scene, toLocal: toLocal, bounds: bounds, includesPulses: bounds == nil)
        TimelineView(.animation(paused: !snapshot.isAnimating)) { timeline in
            HighlightLayer(snapshot: snapshot,
                           now: snapshot.isAnimating ? timeline.date.timeIntervalSinceReferenceDate : 0)
                .equatable()
        }
        .ignoresSafeArea()
    }
}

/// The drawing itself. Equal inputs skip the redraw, which keeps idle displays idle.
private struct HighlightLayer: View, Equatable {
    let snapshot: HighlightSnapshot
    let now: TimeInterval

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, _ in
            snapshot.draw(in: &context, now: now)
        }
    }
}

/// A copy of the scene for one frame, with points moved into the view's own coordinates.
struct HighlightSnapshot: Equatable {
    private(set) var style: HighlightStyle
    private(set) var pointer: CGPoint
    let pulses: [Pulse]
    let hold: Hold?
    let laserDot: LaserDot?
    let strokes: [LaserStroke]
    /// The ring around the pointer, when the pointer is on or near this view.
    let showsPointerRing: Bool

    /// Keeps only what reaches into `bounds`, when given.
    @MainActor
    init(scene: HighlightScene, toLocal local: (CGPoint) -> CGPoint, bounds: CGRect? = nil,
         includesPulses: Bool = true) {
        _ = scene.revision
        style = scene.style
        // The furthest any effect reaches from its point: a ripple at the largest sizes.
        let reach = 44 * scene.style.pointerScale * scene.style.pulseSize * 1.2 + 40
        let near = { (p: CGPoint) in bounds.map { $0.insetBy(dx: -reach, dy: -reach).contains(p) } ?? true }
        pointer = local(scene.pointer)
        showsPointerRing = scene.style.showsRing && near(pointer)
        pulses = !includesPulses ? [] : scene.pulses.map { Pulse(point: local($0.point), start: $0.start) }
            .filter { near($0.point) }
        hold = !includesPulses ? nil : scene.hold.map { Hold(point: local($0.point), start: $0.start, releasedAt: $0.releasedAt) }
            .flatMap { near($0.point) ? $0 : nil }
        laserDot = scene.laserDot.map { LaserDot(point: local($0.point), updatedAt: $0.updatedAt) }
            .flatMap { near($0.point) ? $0 : nil }
        strokes = scene.strokes.map { LaserStroke(points: $0.points.map(local), finishedAt: $0.finishedAt) }
            .filter { $0.points.contains(where: near) }
        // Nothing to draw here: a fixed empty picture, so a new pair or size, as when the pointer
        // moves to another display, doesn't redraw every idle display.
        if isEmpty { (style, pointer) = (HighlightStyle(), .zero) }
    }

    private var isEmpty: Bool { !isAnimating && !showsPointerRing }

    /// Something here is fading, so it needs frames; otherwise one still picture is enough.
    var isAnimating: Bool { !pulses.isEmpty || hold != nil || laserDot != nil || !strokes.isEmpty }

    func draw(in context: inout GraphicsContext, now: TimeInterval) {
        if showsPointerRing { drawRing(in: &context) }
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
