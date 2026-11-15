import CoreGraphics
import Foundation

/// One ice shard: an uneven four- or five-sided crystal that flies straight out from the click,
/// turning a little, and fades.
struct FrostShard: Equatable {
    /// How far out the farthest shard ends, and the largest shard's size, as shares of the radius.
    static let farthest = 1.6
    static let largest = 0.19

    /// The direction it flies, in radians.
    let angle: Double
    /// Where it starts and stops, as shares of the ring's final radius.
    let from: Double
    let to: Double
    /// When it appears, as a share of the pulse length: on the first three frames.
    let leaves: Double
    let size: Double
    let spin: Double
    /// Its corners around its middle, on a unit circle, uneven so no two look alike.
    let corners: [CGPoint]
    /// The tiny ones are sparkles: a dot, not a crystal.
    let isSparkle: Bool

    init(index: Int, of count: Int, start: Double, using random: inout SplitMix) {
        let slot = 2 * .pi / Double(max(count, 1))
        angle = start + slot * Double(index) + Double.random(in: -0.35...0.35, using: &random) * slot
        isSparkle = index % 3 == 2
        from = Double.random(in: 0.6...0.9, using: &random)
        to = Double.random(in: 1.15...Self.farthest, using: &random)
        leaves = Double.random(in: 0.5...2.5, using: &random) * FrostBurst.frame
        size = isSparkle ? Double.random(in: 0.03...0.05, using: &random) : Double.random(in: 0.1...Self.largest, using: &random)
        spin = Double.random(in: -2.2...2.2, using: &random)
        corners = Self.corners(using: &random)
    }

    private static func corners(using random: inout SplitMix) -> [CGPoint] {
        let sides = Bool.random(using: &random) ? 4 : 5
        let turn = Double.random(in: 0..<(2 * .pi), using: &random)
        return (0..<sides).map { side in
            let angle = turn + 2 * .pi * (Double(side) + Double.random(in: -0.2...0.2, using: &random)) / Double(sides)
            let reach = Double.random(in: 0.6...1, using: &random) / 2
            return CGPoint(x: cos(angle) * reach, y: sin(angle) * reach * 1.35)
        }
    }

    /// Its outline at `side` points, around its own middle.
    func outline(side: Double) -> CGPath {
        guard !isSparkle else {
            return CGPath(ellipseIn: CGRect(x: -side / 2, y: -side / 2, width: side, height: side), transform: nil)
        }
        let path = CGMutablePath()
        path.addLines(between: corners.map { CGPoint(x: $0.x * side, y: $0.y * side) })
        path.closeSubpath()
        return path
    }

    /// The shaded face, from its middle out to two neighbouring corners, so it reads as a crystal;
    /// nil for a sparkle.
    func facet(side: Double) -> CGPath? {
        guard !isSparkle, corners.count > 2 else { return nil }
        let path = CGMutablePath()
        let middle = CGPoint(x: corners[0].x * side * 0.15, y: corners[0].y * side * 0.15)
        path.addLines(between: [middle, corners[1], corners[2], corners[3 % corners.count]].enumerated().map { index, point in
            index == 0 ? point : CGPoint(x: point.x * side, y: point.y * side)
        })
        path.closeSubpath()
        return path
    }
}
