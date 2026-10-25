import AppKit
import QuartzCore

/// The ring around the pointer on one display, as a Core Animation layer.
///
/// Following the pointer only moves the layer, like the laser dot (LaserLayerView), so a display
/// the pointer has just reached shows the ring at once instead of first redrawing a full-display
/// picture.
@MainActor
final class RingLayerView: NSView {
    private let ring = CAShapeLayer()
    /// The color and size the ring was last drawn with.
    private var look: (color: RGBA, side: Double)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        ring.isHidden = true
        ring.lineWidth = 3
        layer?.addSublayer(ring)
    }

    required init?(coder: NSCoder) { nil }

    /// Puts the ring at `point`, in this view's coordinates, or hides it when `point` is nil or the
    /// ring is off.
    func place(at point: CGPoint?, style: HighlightStyle) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        guard let point, style.showsRing else { ring.isHidden = true; return }
        restyle(style)
        ring.position = point
        ring.isHidden = false
    }

    private func restyle(_ style: HighlightStyle) {
        let side = 44 * style.pointerScale
        if look?.color == style.ringColor, look?.side == side { return }
        look = (style.ringColor, side)
        ring.path = CGPath(ellipseIn: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), transform: nil)
        ring.fillColor = style.ringColor.cgColor(alpha: 0.18)
        ring.strokeColor = style.ringColor.cgColor(alpha: 0.9)
    }
}
