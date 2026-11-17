import Foundation

/// One flying square of the Bokeh pulse: a rounded square, outlined or filled, that flies straight
/// out from the click along its place in the click's layout and fades while still moving. Its
/// ranges are the ones measured on every square of the clip's 44 clean clicks, in points at the
/// 44 pt base size.
struct BokehTile: Equatable {
    /// The fastest steady speed, in points a frame, and the largest side.
    static let fastest = 12.0
    static let largest = 60.0

    /// The direction it flies, in radians: exactly its place in the layout, as in the clip.
    let angle: Double
    /// How far from the click it starts, and its steady speed in points a frame (6 to 12, median 9).
    let start: Double
    let speed: Double
    /// The frame it starts to fade on; it's gone 2.5 frames later.
    let fades: Double
    /// Its side once it has settled, in points (23 to 68 measured, median 39).
    let side: Double
    /// Filled squares glow solid; the others are outlines, about half and half.
    let isFilled: Bool
    /// Its shade, anywhere from the palette's deepest (0, the clip's orange) to its palest (1, the
    /// clip's pale gold), as measured.
    let shade: Double
    /// The blur it settles to: next to none for outlines, a soft edge for filled squares.
    let rest: Double

    /// A square flying along `direction` in radians.
    init(direction: Double, using random: inout SplitMix) {
        angle = direction
        start = 7
        speed = Double.random(in: 6...Self.fastest, using: &random)
        fades = Double.random(in: 7.5...8.5, using: &random)
        isFilled = Bool.random(using: &random)
        shade = Double.random(in: 0...1, using: &random)
        side = Double.random(in: 25...55, using: &random)
        rest = isFilled ? side / 12 : 1.2
    }
}
