import CoreGraphics

/// The part of the screen a laser screenshot keeps: the trail, its full width, and a margin.
/// Global rects are AppKit's: points, origin at the bottom left of the main display.
enum LaserShotArea {
    /// A drag whose trail is smaller than this on both sides is a click, not a drawing.
    static let minimumDrag = 10.0

    /// The area around a trail whose points lie in `trail` and which reaches `reach` past them, with
    /// `margin` more on every side. Nil for a click or a tiny drag.
    static func area(around trail: CGRect, reach: Double, margin: Double) -> CGRect? {
        guard max(trail.width, trail.height) >= minimumDrag else { return nil }
        let grow = reach + max(margin, 0)
        return trail.insetBy(dx: -grow, dy: -grow)
    }

    /// The display, among `frames`, that holds most of `area`; nil if it's on none of them.
    static func displayIndex(for area: CGRect, among frames: [CGRect]) -> Int? {
        let overlaps = frames.map { size(of: area.intersection($0)) }
        guard let best = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[best] > 0 else { return nil }
        return best
    }

    /// `area` cut to the display at `frame`, in that display's own points with the origin at its
    /// top left, as screen capture wants it, and rounded out to whole points.
    static func sourceRect(_ area: CGRect, on frame: CGRect) -> CGRect? {
        let inside = area.intersection(frame)
        guard size(of: inside) > 0 else { return nil }
        return CGRect(x: inside.minX - frame.minX, y: frame.maxY - inside.maxY,
                      width: inside.width, height: inside.height).integral
    }

    private static func size(of rect: CGRect) -> Double {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
