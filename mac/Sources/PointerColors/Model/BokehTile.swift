import Foundation

/// One flying square of the Bokeh pulse: a rounded square, outlined or filled, pale or warm,
/// that bursts straight out from the click, slows to a stop and fades.
struct BokehTile: Equatable {
    /// How far out the farthest square stops, and the largest square's side, against the base.
    static let farthest = 2.0
    static let largest = 0.95

    /// The direction it flies, in radians.
    let angle: Double
    /// Where it starts and stops, against the base.
    let from: Double
    let to: Double
    /// When it appears and when it starts to fade, as shares of the pulse length.
    let leaves: Double
    let fades: Double
    /// Its side against the base.
    let size: Double
    /// Filled squares glow solid; the others are outlines, about two in three as in the clip.
    let isFilled: Bool
    /// Warm squares take the deeper color, about one in three.
    let isWarm: Bool

    init(index: Int, of count: Int, start: Double, using random: inout SplitMix) {
        let slot = 2 * .pi / Double(max(count, 1))
        angle = start + slot * Double(index) + Double.random(in: -0.3...0.3, using: &random) * slot
        from = Double.random(in: 0.1...0.35, using: &random)
        to = Double.random(in: 1.35...Self.farthest, using: &random)
        leaves = Double.random(in: 0.5...1.5, using: &random) * BokehBurst.tick
        fades = Double.random(in: 5...8, using: &random) * BokehBurst.tick
        size = Double.random(in: 0.45...Self.largest, using: &random)
        isFilled = index % 3 == 1
        isWarm = index % 3 == 2 || Double.random(in: 0..<1, using: &random) < 0.15
    }
}
