import AppKit
import QuartzCore

/// The laser dot and its drag trail on one display, as Core Animation layers.
///
/// Like the pulses (PulseLayerView), the dot is moved and its fade handed to Core Animation, so
/// following the pointer costs no drawing in the app. Drawn in SwiftUI, a display the pointer had
/// just reached had to start redrawing a full-display picture first, and the dot lagged behind.
@MainActor
final class LaserLayerView: NSView {
    /// The dot's glow, outline, middle and center, and the colors and size they were built with.
    private var dot: CALayer?
    private var dotLook: (colors: LaserColors, size: Double)?
    /// The part of the trail being drawn: its four lines share one path.
    private var stroke: CALayer?
    private var strokePath = CGMutablePath()
    private var lastPoint: CGPoint?
    /// Earlier parts of the same trail, drawn in another pair's colors before the pointer reached
    /// a display with its own pair. They fade together with the rest.
    private var earlierParts: [CALayer] = []
    private var strokeLook: (colors: LaserColors, size: Double)?

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

    /// The dot, rebuilt when the laser's colors or size changed. It rests invisible; only its fade
    /// shows it.
    private func dotLayer(_ style: HighlightStyle) -> CALayer {
        if let dot, dotLook?.colors == style.laser, dotLook?.size == style.laserSize { return dot }
        dot?.removeFromSuperlayer()
        let parts: [(RGBA, Double, Double)] = [(style.laser.glow, 32, 0.18), (style.laser.outline, 16, 1),
                                               (style.laser.middle, 13, 1), (style.laser.center, 11, 1)]
        let made = CALayer()
        made.opacity = 0
        for (color, side, opacity) in parts {
            let disc = CAShapeLayer()
            let width = side * style.laserSize
            disc.path = CGPath(ellipseIn: CGRect(x: -width / 2, y: -width / 2, width: width, height: width),
                               transform: nil)
            disc.fillColor = color.cgColor(alpha: opacity)
            made.addSublayer(disc)
        }
        withoutAnimation { layer?.addSublayer(made) }
        (dot, dotLook) = (made, (style.laser, style.laserSize))
        return made
    }

    // MARK: Trail

    /// Starts a trail at `point`.
    func startStroke(at point: CGPoint, style: HighlightStyle) {
        finishStroke(fade: style.trailFade)
        beginPart(at: point, style: style)
        extendStroke(to: point, style: style, minimum: 0)
    }

    /// The pair changed mid-trail, as when the pointer reaches another display: the trail goes
    /// on from its last point in the new colors, and what's drawn so far keeps its own.
    func restyleStroke(_ style: HighlightStyle) {
        guard let stroke, let lastPoint else { return }
        guard strokeLook?.colors != style.laser || strokeLook?.size != style.laserSize else { return }
        earlierParts.append(stroke)
        beginPart(at: lastPoint, style: style)
    }

    private func beginPart(at point: CGPoint, style: HighlightStyle) {
        let parts: [(RGBA, Double, Double)] = [(style.laser.glow, 14, 0.2), (style.laser.outline, 6, 1),
                                               (style.laser.middle, 4, 1), (style.laser.center, 2, 1)]
        let made = CALayer()
        made.opacity = 0.95
        for (color, width, opacity) in parts {
            let line = CAShapeLayer()
            line.fillColor = nil
            line.strokeColor = color.cgColor(alpha: opacity)
            line.lineWidth = width * style.laserSize
            line.lineCap = .round
            line.lineJoin = .round
            made.addSublayer(line)
        }
        withoutAnimation { layer?.addSublayer(made) }
        stroke = made
        strokeLook = (style.laser, style.laserSize)
        strokePath = CGMutablePath()
        strokePath.move(to: point)
        lastPoint = point
    }

    /// Adds a point to the trail, skipping ones too close to the last. Starts one if none is open.
    func extendStroke(to point: CGPoint, style: HighlightStyle, minimum: Double = 2.5) {
        guard let stroke, let lastPoint else { return startStroke(at: point, style: style) }
        guard minimum == 0 || hypot(lastPoint.x - point.x, lastPoint.y - point.y) >= minimum else { return }
        strokePath.addLine(to: point)
        self.lastPoint = point
        let path = strokePath.copy()
        withoutAnimation { stroke.sublayers?.forEach { ($0 as? CAShapeLayer)?.path = path } }
    }

    /// The button came up: the trail fades over `fade` seconds, then goes.
    func finishStroke(fade: Double) {
        guard let stroke else { return }
        let parts = earlierParts + [stroke]
        (self.stroke, lastPoint, earlierParts) = (nil, nil, [])
        parts.forEach { fadeOut($0, over: fade) }
    }

    private func fadeOut(_ done: CALayer, over fade: Double) {
        let out = CABasicAnimation(keyPath: "opacity")
        out.fromValue = 0.95
        out.toValue = 0
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
