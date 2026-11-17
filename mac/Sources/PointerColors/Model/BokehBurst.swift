import Foundation

/// The Bokeh pulse at any moment, as plain numbers both the overlay and the Preferences preview
/// draw from. It reproduces the reference clip: one glowing rounded square that flashes large
/// around the click and shrinks into the pointer, while a few rounded squares burst out of it.
///
/// Measured frame by frame at 60 fps on the clip's first two clicks, which match exactly in the
/// middle square, and checked against 45 clicks for the flying squares, which differ every click.
/// Sizes are points at the 44 pt base size (Size 1×) and scale with Size. The clip plays in 13
/// frames, so Bokeh always plays for `clipLength`.
struct BokehBurst {
    /// The pulse's base size in points, 44 at Size 1×.
    let base: Double
    /// How soft every part is against the clip: 1 is the clip's blur and glow, 0 is sharp shapes
    /// with no glow, 2 twice as soft.
    var softness = 1.0

    /// How solid the glow around each line is: full from the clip's softness up, fading to none
    /// as the shapes turn sharp.
    var haloStrength: Double { min(max(softness, 0), 1) }

    /// The clip's length: 13 frames at 60 fps.
    static let frames = 13.0
    static let clipLength = frames / 60

    /// The reference frame `time` falls on, from 0 to 13.
    static func frame(_ time: Double) -> Double { min(max(time, 0), 1) * frames }

    private var scale: Double { base / 44 }

    // MARK: Middle square

    /// The middle square's side on each frame, measured on both clicks (frames 1 to 3, hidden
    /// under the squares, follow the curve between frames 0 and 4).
    static let middleSides = [164, 147, 131, 115, 100, 86, 73.5, 61.5, 50, 40.5, 31.5, 23, 16.5, 10]
    /// How solid it is: whole until frame 11, dimmer on 12, gone by 13.
    static let middleOpacities = [1.0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.7, 0]
    /// Its line, thick and soft at first, thinner and sharper as it shrinks.
    static let middleLines = [10.0, 9.5, 9, 8.5, 8, 7, 6.5, 6, 5.5, 5, 4.5, 4, 3.5, 3]
    static let middleBlurs = [7.0, 6, 5.2, 4.5, 3.8, 3.2, 2.6, 2.1, 1.7, 1.4, 1.1, 0.9, 0.7, 0.5]
    /// The soft halo around the line.
    static let middleGlows = [18.0, 16, 14, 12.5, 11, 9.5, 8, 6.5, 5.5, 4.5, 3.5, 3, 2.5, 2]

    /// The square that flashes around the click and shrinks into the pointer.
    func middle(at time: Double) -> Square {
        let frame = Self.frame(time)
        return Square(side: scale * Self.value(Self.middleSides, at: frame),
                      opacity: Self.value(Self.middleOpacities, at: frame),
                      blur: softness * scale * Self.value(Self.middleBlurs, at: frame))
    }

    func middleLineWidth(at time: Double) -> Double { scale * Self.value(Self.middleLines, at: Self.frame(time)) }
    func middleGlow(at time: Double) -> Double { softness * scale * Self.value(Self.middleGlows, at: Self.frame(time)) }

    /// The halo is a wider, fainter copy of the line.
    static let glowWidth = 2.2
    static let glowOpacity = 0.85

    // MARK: Flying squares

    /// Where square `tile` is at `time`, around the click, and how solid and soft it is. Each
    /// leaves the middle on frame 1, fast at first, then keeps a steady speed of its own while it fades.
    func place(_ tile: BokehTile, at time: Double) -> (center: CGPoint, square: Square) {
        let frame = Self.frame(time)
        let flown = max(frame - 1, 0)
        let burst = 1 - pow(1 - min(flown / 4, 1), 2)
        let distance = scale * (tile.start + tile.speed * flown + tile.speed * Self.burstReach * burst)
        let center = CGPoint(x: cos(tile.angle) * distance, y: sin(tile.angle) * distance)
        let grown = 1 + 0.5 * (1 - min(flown / 4, 1))
        let shown = Self.share(frame, from: 0.3, to: 0.8)
        let fade = Self.share(frame, from: tile.fades, to: tile.fades + 2.5)
        let square = Square(side: scale * tile.side * grown, opacity: shown * (1 - fade), blur: blur(of: tile, at: frame))
        return (center, square)
    }

    /// How far the opening burst carries a square beyond its steady speed, in frames of that
    /// speed: across the clip, squares are 51 to 99 pt out on frame 6 at 6 to 12 pt a frame.
    static let burstReach = 2.5

    /// A flying square's line, as in the clip, and the soft halo each outline has around it:
    /// that much wider, that much more blurred and that solid.
    var lineWidth: Double { max(scale * 3, 1) }
    var outlineGlowBlur: Double { softness * scale * 3 }
    static let outlineGlowWidth = 2.5
    static let outlineGlowOpacity = 0.6

    /// Soft as it leaves, settling by frame 6 to its own blur: sharp for outlines, soft for fills.
    private func blur(of tile: BokehTile, at frame: Double) -> Double {
        let settle = Self.share(frame, from: 1, to: 6)
        return softness * scale * (tile.rest + (Self.leavingBlur - tile.rest) * (1 - settle))
    }

    /// How blurred every square is as it leaves, in points at the base size.
    static let leavingBlur = 4.0

    /// How far the burst reaches from the click at its widest, glow and blur included.
    var reach: Double {
        let soft = max(softness, 1)
        let tiles = BokehTile.fastest * (Self.frames - 1 + Self.burstReach) + BokehTile.largest * 0.75 + Self.leavingBlur * 3 * soft + 6
        let middle = Self.middleSides[0] / 2 * 1.3 + Self.middleGlows[0] * 3 * soft
        return scale * max(tiles, middle)
    }

    /// The squares for one click, the same ones for the same seed. As in every click of the clip,
    /// they sit evenly around the click starting straight to the right: five (a pentagon) on three
    /// clicks in four, otherwise four (a cross), three (a triangle) or two (left and right).
    /// With `shapes`, only those, each as likely as the others.
    static func tiles(seed: UInt64, shapes: [BokehShape]? = nil) -> [BokehTile] {
        var random = SplitMix(seed: seed)
        let roll = Double.random(in: 0..<1, using: &random)
        let count = shapes.flatMap { pick(from: $0, roll: roll)?.count } ?? layoutCount(roll)
        return (0..<count).map { BokehTile(direction: 2 * .pi * Double($0) / Double(count), using: &random) }
    }

    /// How many squares a click sends out, from a roll between 0 and 1: 33 of the clip's 44 clean
    /// clicks have five, 5 have four, 3 have three and 3 have two.
    /// One of `shapes` for a roll between 0 and 1, each as likely; nil when there are none.
    static func pick(from shapes: [BokehShape], roll: Double) -> BokehShape? {
        guard !shapes.isEmpty else { return nil }
        return shapes[min(Int(roll * Double(shapes.count)), shapes.count - 1)]
    }

    static func layoutCount(_ roll: Double) -> Int {
        let chances: [(count: Int, upTo: Double)] = [(5, 0.75), (4, 0.86), (3, 0.93)]
        return chances.first { roll < $0.upTo }?.count ?? 2
    }

    /// `values` read at `frame`, eased linearly between whole frames.
    static func value(_ values: [Double], at frame: Double) -> Double {
        let low = min(Int(frame), values.count - 1)
        let high = min(low + 1, values.count - 1)
        return values[low] + (values[high] - values[low]) * (frame - Double(low))
    }

    /// How far `value` is between `from` and `to`, from 0 to 1.
    static func share(_ value: Double, from: Double, to: Double) -> Double {
        min(max((value - from) / max(to - from, 0.0001), 0), 1)
    }

    /// A rounded square at one moment: its side in points, how solid it is and its blur radius.
    struct Square: Equatable {
        var side: Double
        var opacity: Double
        var blur: Double

        /// How round its corners are, as a share of its side, as in the clip.
        static let cornerShare = 0.25
        var cornerRadius: Double { side * Self.cornerShare }
    }
}
