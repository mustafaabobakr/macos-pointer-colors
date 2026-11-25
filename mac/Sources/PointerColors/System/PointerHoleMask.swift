import QuartzCore

/// A mask that leaves everything visible except a tiny square under the pointer.
///
/// Shottr and CleanShot pick the window to capture by the topmost window with a drawn pixel right
/// under the pointer. A ring, pulse or laser dot there, even a faint one, made them pick the
/// overlay's full-display window instead of the window below. The hole sits under the pointer's
/// hotspot, so the cursor covers it. It's built from four plain layers around the hole, so following
/// the pointer only moves them and never redraws a full-display picture.
@MainActor
final class PointerHoleMask: CALayer {
    /// Half the hole's side, in points. A 1 pt radius was enough for both apps on a 1x display.
    static let halfSide = 1.0

    private let parts = (0..<4).map { _ in CALayer() }

    override init() {
        super.init()
        for part in parts {
            part.backgroundColor = CGColor(gray: 0, alpha: 1)
            addSublayer(part)
        }
    }

    override init(layer: Any) { super.init(layer: layer) }

    required init?(coder: NSCoder) { nil }

    /// Covers `bounds`, with the hole at `point` (in the same coordinates). With `point` nil or
    /// off `bounds`, as when the pointer is on another display, there's no hole.
    func place(hole point: CGPoint?, in bounds: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        frame = bounds
        let local = CGRect(origin: .zero, size: bounds.size)
        let hole = point.map {
            CGRect(x: $0.x - bounds.minX - Self.halfSide, y: $0.y - bounds.minY - Self.halfSide,
                   width: Self.halfSide * 2, height: Self.halfSide * 2)
        } ?? .null
        zip(parts, Self.pieces(of: local, around: hole)).forEach { $0.frame = $1 }
    }

    /// Below, above, left of and right of `hole`, together covering `bounds` but the hole.
    static func pieces(of bounds: CGRect, around hole: CGRect) -> [CGRect] {
        guard !hole.isNull, bounds.intersects(hole) else { return [bounds, .zero, .zero, .zero] }
        let below = CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(hole.minY - bounds.minY, 0))
        let above = CGRect(x: bounds.minX, y: hole.maxY, width: bounds.width, height: max(bounds.maxY - hole.maxY, 0))
        let left = CGRect(x: bounds.minX, y: hole.minY, width: max(hole.minX - bounds.minX, 0), height: hole.height)
        let right = CGRect(x: hole.maxX, y: hole.minY, width: max(bounds.maxX - hole.maxX, 0), height: hole.height)
        return [below, above, left, right]
    }
}
