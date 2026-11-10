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
    /// What the ring was last drawn with.
    private var look: RingLook?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        ring.isHidden = true
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
        let new = RingLook(style)
        guard new != look else { return }
        look = new
        let side = new.side
        ring.path = CGPath(ellipseIn: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), transform: nil)
        ring.fillColor = new.color.cgColor(alpha: new.fill)
        ring.strokeColor = new.color.cgColor(alpha: new.opacity)
        ring.lineWidth = new.lineWidth
    }
}

/// Everything the ring is drawn with, to tell when it needs drawing again.
private struct RingLook: Equatable {
    let color: RGBA
    let side: Double
    let fill: Double
    let lineWidth: Double
    let opacity: Double

    init(_ style: HighlightStyle) {
        color = style.ringColor
        side = 44 * style.pointerScale * style.ringSize
        (fill, lineWidth, opacity) = (style.ringFill, style.ringLineWidth, style.ringOpacity)
    }
}
