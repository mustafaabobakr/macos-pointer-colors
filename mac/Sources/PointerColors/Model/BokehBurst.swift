import Foundation

/// The Bokeh pulse at any moment, as plain numbers both the overlay and the Preferences preview
/// draw from: a glowing rounded-square frame that flashes around the click and shrinks away, a
/// square that stays on the pointer and shrinks, and rounded squares that burst out, coming into
/// focus as they fly.
///
/// Measured frame by frame from a 60 fps reference clip, where the burst lasts 16 frames at a
/// 44 pt base size: the frame shows at its full 3.4× the base on frame 0, shrinks to 0.8 of that
/// and is gone by frame 4; the squares leave on frames 1 and 2, blurred, are sharp by frame 6,
/// slow to a stop 1.4 to 2 times the base out by frame 9 and fade between frames 5 and 11; the
/// middle square holds its size until frame 8, then shrinks until frame 16. Every time here is a share of the pulse length, so the Length setting
/// stretches it all evenly.
struct BokehBurst {
    /// The pulse's base size in points, 44 at Size 1×. Everything is sized against it.
    let base: Double
    /// Whether the squares start blurred and come into focus, as in the clip; off keeps them sharp.
    let focus: Bool

    /// One reference frame, as a share of the pulse length.
    static let tick = 1.0 / 16
    /// When every square is sharp.
    static let sharpAt = 6 * tick
    /// When the flying squares stop.
    static let landsAt = 9 * tick

    // MARK: Glow frame

    /// The large glowing square of the first frames: full size at once, shrinking as it fades.
    func glowFrame(at time: Double) -> Square {
        let shrink = 1 - pow(1 - Self.share(time, from: 0, to: 3 * Self.tick), 2)
        let fade = Self.share(time, from: 2.5 * Self.tick, to: 4 * Self.tick)
        return Square(side: base * Self.frameSide * (1 - 0.2 * shrink), opacity: 1 - fade, blur: frameBlur)
    }

    /// The glow frame's side at first, against the base; its line; and how soft that line is.
    static let frameSide = 3.4
    var frameLineWidth: Double { base * 0.15 }
    var frameBlur: Double { base * 0.18 }

    // MARK: Middle square

    /// The outlined square that stays on the pointer, shrinking until the burst ends.
    func middle(at time: Double) -> Square {
        let shown = Self.share(time, from: 0.5 * Self.tick, to: Self.tick)
        let fade = Self.share(time, from: 13 * Self.tick, to: 1)
        let side = base * (1 - 0.8 * Self.share(time, from: 8 * Self.tick, to: 1))
        return Square(side: side, opacity: shown * (1 - fade), blur: blur(at: time, from: 0.5 * Self.tick))
    }

    // MARK: Flying squares

    /// Where square `tile` is at `time`, around the click, and how solid and soft it is.
    func place(_ tile: BokehTile, at time: Double) -> (center: CGPoint, square: Square) {
        let flight = Self.share(time, from: tile.leaves, to: Self.landsAt)
        let eased = 1 - pow(1 - flight, 3)
        let distance = base * (tile.from + (tile.to - tile.from) * eased)
        let center = CGPoint(x: cos(tile.angle) * distance, y: sin(tile.angle) * distance)
        let shown = Self.share(time, from: tile.leaves, to: tile.leaves + 0.5 * Self.tick)
        let fade = Self.share(time, from: tile.fades, to: tile.fades + 3 * Self.tick)
        let square = Square(side: base * tile.size, opacity: shown * (1 - fade), blur: blur(at: time, from: tile.leaves))
        return (center, square)
    }

    /// A square's line, about 3.5 pt at the 44 pt base.
    var lineWidth: Double { max(base * 0.08, 1) }

    /// The blur of a square that appeared at `start`: soft at first, sharp from `sharpAt`.
    func blur(at time: Double, from start: Double) -> Double {
        guard focus else { return 0 }
        return maxBlur * (1 - Self.share(time, from: start, to: Self.sharpAt))
    }

    /// The most a square is blurred, as it appears.
    var maxBlur: Double { base * 0.22 }

    /// How far the burst reaches from the click at its widest, glow and blur included.
    var reach: Double {
        let tiles = BokehTile.farthest + BokehTile.largest * 0.75
        let frame = Self.frameSide / 2 * 1.3 + 0.15
        return base * max(tiles, frame) + max(maxBlur, frameBlur) * 2
    }

    /// `count` squares spread around the click, the same ones for the same seed.
    static func tiles(count: Int, seed: UInt64) -> [BokehTile] {
        var random = SplitMix(seed: seed)
        let start = Double.random(in: 0..<(2 * .pi), using: &random)
        return (0..<count).map { BokehTile(index: $0, of: count, start: start, using: &random) }
    }

    /// How far `time` is between `from` and `to`, from 0 to 1.
    static func share(_ time: Double, from: Double, to: Double) -> Double {
        min(max((time - from) / max(to - from, 0.0001), 0), 1)
    }

    /// A rounded square at one moment: its side in points, how solid it is and its blur radius.
    struct Square: Equatable {
        var side: Double
        var opacity: Double
        var blur: Double

        /// How round its corners are, as a share of its side, as in the clip.
        static let cornerShare = 0.24
        var cornerRadius: Double { side * Self.cornerShare }
    }
}
