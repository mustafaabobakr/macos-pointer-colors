import AppKit
import QuartzCore

/// Click pulses and the long-press ring on one display, as Core Animation layers.
///
/// Each pulse is a shape layer with its grow-and-fade animation handed to Core Animation, which
/// plays it without the app drawing a single frame. Redrawing a full-display picture for every
/// frame of a pulse is what made clicks stutter: each frame had to be handed over from the main
/// thread, holding up the mouse events behind it.
@MainActor
final class PulseLayerView: NSView {
    /// The long-press ring while it's shown, and whether it is waiting to appear.
    private var holdLayer: CAShapeLayer?
    private var pendingHold: DispatchWorkItem?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { nil }

    /// Sends out a pulse at `point`, in this view's coordinates (origin bottom left).
    func pulse(at point: CGPoint, style: HighlightStyle) {
        switch style.pulseStyle {
        case .ring: addRing(at: point, style: style)
        case .ripple: (0..<3).forEach { addRippleWave($0, at: point, style: style) }
        }
    }

    /// Shows the long-press ring at `point` if the press lasts past a click.
    func beginHold(at point: CGPoint, style: HighlightStyle) {
        endHold(fadeOut: false)
        let work = DispatchWorkItem { [weak self] in self?.showHold(at: point, style: style) }
        pendingHold = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Hold.threshold, execute: work)
    }

    /// Keeps the ring under the pointer while the button is held.
    func moveHold(to point: CGPoint) {
        guard let holdLayer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        holdLayer.position = point
        CATransaction.commit()
    }

    /// The button came up. A ring that was showing fades; a press too short for one shows nothing.
    /// True when it was a long press, so the caller sends out the release pulse.
    @discardableResult
    func endHold(fadeOut: Bool = true) -> Bool {
        pendingHold?.cancel()
        pendingHold = nil
        guard let ring = holdLayer else { return false }
        holdLayer = nil
        guard fadeOut else { ring.removeFromSuperlayer(); return false }
        animate(ring, key: "opacity", from: ring.presentation()?.opacity ?? 1, to: 0, duration: Hold.release) {
            ring.removeFromSuperlayer()
        }
        return true
    }

    // MARK: Layers

    private func addRing(at point: CGPoint, style: HighlightStyle) {
        let base = baseDiameter(style)
        let ring = circleLayer(at: point, color: style.pulseColor, lineWidth: 4)
        animate(ring, duration: style.pulseDuration, timing: .easeOut, changes: [
            ("path", circle(Pulse.startSide), circle(base * 1.8)),
            ("opacity", 0.95, 0),
        ])
    }

    /// One of three waves, each leaving a little after the one before.
    private func addRippleWave(_ index: Int, at point: CGPoint, style: HighlightStyle) {
        let base = baseDiameter(style)
        let wave = circleLayer(at: point, color: style.pulseColor, lineWidth: 3)
        wave.opacity = 0
        let delay = style.pulseDuration * 0.15 * Double(index)
        animate(wave, duration: style.pulseDuration * 0.7, delay: delay, timing: .easeOut, changes: [
            ("path", circle(Pulse.startSide), circle(base * 2.2)),
            ("lineWidth", 3, 1),
            ("opacity", 0.9, 0),
        ])
    }

    private func showHold(at point: CGPoint, style: HighlightStyle) {
        pendingHold = nil
        let side = baseDiameter(style) * Hold.size
        let ring = circleLayer(at: point, color: style.pulseColor, lineWidth: 3)
        ring.path = circle(side)
        ring.fillColor = style.pulseColor.cgColor(alpha: 0.35)
        holdLayer = ring
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.6
        grow.toValue = 1
        grow.duration = Hold.grow
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 1
        breathe.toValue = 1.04
        breathe.duration = 0.6
        breathe.beginTime = CACurrentMediaTime() + Hold.grow
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        ring.add(grow, forKey: "grow")
        ring.add(breathe, forKey: "breathe")
    }

    /// A circle layer centred on `point`; its path is drawn around the layer's own origin.
    private func circleLayer(at point: CGPoint, color: RGBA, lineWidth: CGFloat) -> CAShapeLayer {
        let shape = CAShapeLayer()
        shape.position = point
        shape.fillColor = nil
        shape.strokeColor = color.cgColor(alpha: 1)
        shape.lineWidth = lineWidth
        layer?.addSublayer(shape)
        return shape
    }

    private func circle(_ side: Double) -> CGPath {
        CGPath(ellipseIn: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), transform: nil)
    }

    private func baseDiameter(_ style: HighlightStyle) -> Double {
        44 * style.pointerScale * style.pulseSize
    }

    /// Runs several property animations together, holds the end state, then removes the layer.
    private func animate(_ shape: CAShapeLayer, duration: Double, delay: Double = 0,
                         timing: CAMediaTimingFunctionName, changes: [(String, Any, Any)]) {
        let group = CAAnimationGroup()
        group.animations = changes.map { key, from, to in
            let step = CABasicAnimation(keyPath: key)
            step.fromValue = from
            step.toValue = to
            return step
        }
        group.duration = duration
        group.beginTime = CACurrentMediaTime() + delay
        group.timingFunction = CAMediaTimingFunction(name: timing)
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false
        CATransaction.begin()
        CATransaction.setCompletionBlock { shape.removeFromSuperlayer() }
        shape.add(group, forKey: "pulse")
        CATransaction.commit()
    }

    private func animate(_ shape: CAShapeLayer, key: String, from: Float, to: Float, duration: Double,
                         completion: @escaping () -> Void) {
        let step = CABasicAnimation(keyPath: key)
        step.fromValue = from
        step.toValue = to
        step.duration = duration
        step.fillMode = .forwards
        step.isRemovedOnCompletion = false
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        shape.add(step, forKey: key)
        CATransaction.commit()
    }
}

extension RGBA {
    func cgColor(alpha scale: Double) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha * scale)
    }
}
