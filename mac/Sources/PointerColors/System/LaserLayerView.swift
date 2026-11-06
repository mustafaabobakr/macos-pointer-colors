import AppKit
import QuartzCore

/// The laser dot and its drag trail on one display, as Core Animation layers.
///
/// Like the pulses (PulseLayerView), the dot is moved and its fade handed to Core Animation, so
/// following the pointer costs no drawing in the app. Drawn in SwiftUI, a display the pointer had
/// just reached had to start redrawing a full-display picture first, and the dot lagged behind.
@MainActor
final class LaserLayerView: NSView {
    /// The dot's layers, and the parts they were built from.
    private var dot: CALayer?
    private var dotLook: [LaserPart]?
    /// The part of the trail being drawn: its lines share one path.
    private var stroke: CALayer?
    private var strokePath = CGMutablePath()
    private var lastPoint: CGPoint?
    /// Earlier parts of the same trail, drawn in another pair's colors before the pointer reached
    /// a display with its own pair. They fade together with the rest.
    private var earlierParts: [CALayer] = []
    private var strokeLook: [LaserPart]?
    /// The GoodNotes look's trail, one path per part, widths following the pointer's speed;
    /// nil for Classic, whose lines share `strokePath`.
    private var shape: LaserTrailShape?
    private var pace = LaserPace()
    private var lastShare = 1.0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { nil }

    // MARK: Dot

    /// Puts the dot at `point`, in this view's coordinates, and starts its fade over again.
    func moveDot(to point: CGPoint, style: HighlightStyle) {
        let dot = dotLayer(style)
        withoutAnimation { dot.position = point }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = LaserDot.fade
        dot.add(fade, forKey: "fade")
    }

    /// The pointer left this display: the dot goes at once.
    func hideDot() {
        dot?.removeAnimation(forKey: "fade")
    }

    /// The dot, rebuilt when the laser's look, colors or size changed. It rests invisible; only its
    /// fade shows it.
    private func dotLayer(_ style: HighlightStyle) -> CALayer {
        let parts = style.laserDotParts
        if let dot, dotLook == parts { return dot }
        dot?.removeFromSuperlayer()
        let made = CALayer()
        made.opacity = 0
        for part in parts {
            let disc = CAShapeLayer()
            let width = part.width
            disc.path = CGPath(ellipseIn: CGRect(x: -width / 2, y: -width / 2, width: width, height: width),
                               transform: nil)
            disc.fillColor = part.color.cgColor(alpha: part.opacity)
            glow(disc, part)
            made.addSublayer(disc)
        }
        withoutAnimation { layer?.addSublayer(made) }
        (dot, dotLook) = (made, parts)
        return made
    }

    /// Gives a layer the part's glow: a shadow in its own color, centered under it.
    private func glow(_ shape: CAShapeLayer, _ part: LaserPart) {
        guard part.blur > 0 else { return }
        shape.shadowColor = part.color.cgColor(alpha: 1)
        shape.shadowRadius = part.blur
        shape.shadowOpacity = 1
        shape.shadowOffset = .zero
    }

    // MARK: Trail

    /// Starts a trail at `point`, reached at `time`.
    func startStroke(at point: CGPoint, style: HighlightStyle, time: TimeInterval = CACurrentMediaTime()) {
        finishStroke(style: style)
        pace = LaserPace()
        lastShare = pace.share(at: point, time: time)
        beginPart(at: point, style: style)
        extendStroke(to: point, style: style, minimum: 0, time: time)
    }

    /// The pair changed mid-trail, as when the pointer reaches another display: the trail goes
    /// on from its last point in the new colors, and what's drawn so far keeps its own.
    func restyleStroke(_ style: HighlightStyle) {
        guard let stroke, let lastPoint else { return }
        guard strokeLook != style.laserTrailParts else { return }
        earlierParts.append(stroke)
        beginPart(at: lastPoint, style: style)
    }

    private func beginPart(at point: CGPoint, style: HighlightStyle) {
        let parts = style.laserTrailParts
        let made = CALayer()
        made.opacity = Float(style.trailOpacity)
        let byPace = style.trailVariesWithSpeed
        for part in parts {
            let line = byPace ? ribbonLayer(part) : lineLayer(part)
            glow(line, part)
            made.addSublayer(line)
        }
        withoutAnimation { layer?.addSublayer(made) }
        stroke = made
        strokeLook = parts
        strokePath = CGMutablePath()
        strokePath.move(to: point)
        lastPoint = point
        shape = byPace ? LaserTrailShape(parts: parts, points: [point], shares: [lastShare]) : nil
    }

    private func lineLayer(_ part: LaserPart) -> CAShapeLayer {
        let line = CAShapeLayer()
        line.fillColor = nil
        line.strokeColor = part.color.cgColor(alpha: part.opacity)
        line.lineWidth = part.width
        line.lineCap = .round
        line.lineJoin = .round
        return line
    }

    private func ribbonLayer(_ part: LaserPart) -> CAShapeLayer {
        let ribbon = CAShapeLayer()
        ribbon.fillColor = part.color.cgColor(alpha: part.opacity)
        ribbon.strokeColor = nil
        return ribbon
    }

    /// Adds a point to the trail, skipping ones too close to the last. Starts one if none is open.
    func extendStroke(to point: CGPoint, style: HighlightStyle, minimum: Double = 2.5,
                      time: TimeInterval = CACurrentMediaTime()) {
        guard let stroke, let lastPoint else { return startStroke(at: point, style: style, time: time) }
        guard minimum == 0 || hypot(lastPoint.x - point.x, lastPoint.y - point.y) >= minimum else { return }
        self.lastPoint = point
        lastShare = pace.share(at: point, time: time)
        if let shape { return extend(shape, to: point, in: stroke) }
        strokePath.addLine(to: point)
        let path = strokePath.copy()
        withoutAnimation { stroke.sublayers?.forEach { ($0 as? CAShapeLayer)?.path = path } }
    }

    /// Adds the point at the current pace's width and redraws each part.
    private func extend(_ shape: LaserTrailShape, to point: CGPoint, in stroke: CALayer) {
        shape.add(point, share: lastShare)
        let layers = stroke.sublayers ?? []
        withoutAnimation {
            for (layer, path) in zip(layers, shape.paths) { (layer as? CAShapeLayer)?.path = path }
        }
    }

    /// The button came up: the trail stays for the style's hold, fades by the end of its
    /// `trailFade`, then goes.
    func finishStroke(style: HighlightStyle) {
        guard let stroke else { return }
        let parts = earlierParts + [stroke]
        (self.stroke, lastPoint, earlierParts, shape) = (nil, nil, [], nil)
        parts.forEach { fadeOut($0, style: style) }
    }

    private func fadeOut(_ done: CALayer, style: HighlightStyle) {
        let fade = max(style.trailFade, 0.01)
        let out = CAKeyframeAnimation(keyPath: "opacity")
        out.values = [done.opacity, done.opacity, 0]
        out.keyTimes = [0, NSNumber(value: style.trailHold / fade), 1]
        out.duration = fade
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setCompletionBlock { done.removeFromSuperlayer() }
        done.opacity = 0
        done.add(out, forKey: "fade")
        CATransaction.commit()
    }

    private func withoutAnimation(_ change: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        change()
        CATransaction.commit()
    }
}
