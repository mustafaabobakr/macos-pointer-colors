import CoreGraphics

/// Which part of a display Smart zoom shows, in unit coordinates from the display's top left.
/// Either way the spot under the pointer stays under it, so a click lands on what it shows.
enum ZoomGeometry {
    /// The whole display, magnified `amount` times around the pointer at `pointer`.
    static func wholeScreen(pointer: CGPoint, amount: Double) -> CGRect {
        let size = 1 / amount
        return CGRect(x: pointer.x * (1 - size), y: pointer.y * (1 - size), width: size, height: size)
    }

    /// A lens of `lens` size, in units of the display, centred on the pointer.
    static func lens(pointer: CGPoint, amount: Double, lens: CGSize) -> CGRect {
        let width = lens.width / amount
        let height = lens.height / amount
        return CGRect(x: pointer.x - width / 2, y: pointer.y - height / 2, width: width, height: height)
    }

    /// `point` moved inside `frame`, `margin` points from its edges.
    static func kept(_ point: CGPoint, inside frame: CGRect, margin: CGFloat) -> CGPoint {
        let inner = frame.insetBy(dx: margin, dy: margin)
        return CGPoint(x: min(max(point.x, inner.minX), inner.maxX), y: min(max(point.y, inner.minY), inner.maxY))
    }

    /// `rect` in Core Animation's unit space for a layer's contents, which starts at the bottom.
    static func layerRect(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: 1 - rect.maxY, width: rect.width, height: rect.height)
    }
}
