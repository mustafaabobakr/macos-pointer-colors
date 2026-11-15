import Foundation

/// The Frost pulse at any moment, as plain numbers both the overlay and the Preferences preview
/// draw from: a white flash, a glowing ring with a fainter one inside it, and ice shards flying out.
///
/// Measured frame by frame from a 30 fps reference clip, where the whole burst lasts 14 frames:
/// the flash fills frame 0, the ring grows from a quarter of its final radius to all of it over
/// frames 1 to 6 and is gone by frame 7, and the shards keep drifting out until about frame 14.
/// Every time here is a share of the pulse length, so the Length setting stretches it all evenly.
struct FrostBurst {
    /// The ring's radius at its widest, in points. Everything else is sized against it.
    let radius: Double

    /// One reference frame, as a share of the pulse length.
    static let frame = 1.0 / 14
    /// When the ring is gone.
    static let ringEnd = 7 * frame

    // MARK: Flash

    /// The white disc of the first frame: 35% of the final radius, gone by the next frame.
    func flashCore(at time: Double) -> Circle {
        let shown = 1 - Self.share(time, from: 0.4 * Self.frame, to: 1.3 * Self.frame)
        return Circle(radius: radius * (0.35 + 0.08 * Self.share(time, from: 0, to: Self.frame)), opacity: shown)
    }

    /// The soft pale-blue glow around the flash, reaching well past the final ring, fading over
    /// the next three frames.
    func flashGlow(at time: Double) -> Circle {
        let fade = Self.share(time, from: Self.frame, to: 4.5 * Self.frame)
        return Circle(radius: radius * (Self.flashReach - 0.4 * fade), opacity: pow(1 - fade, 1.6))
    }

    /// How far the flash's glow reaches at first, as a share of the radius.
    static let flashReach = 1.4

    // MARK: Ring

    /// The bright ring: it leaves at a quarter of its final radius on frame 1, slows as it widens,
    /// and fades from frame 3.
    func ring(at time: Double) -> Circle {
        let grow = Self.share(time, from: Self.frame, to: 6 * Self.frame)
        let eased = 1 - pow(1 - grow, 2.3)
        let shown = Self.share(time, from: 0.6 * Self.frame, to: Self.frame)
        let fade = Self.share(time, from: 3 * Self.frame, to: Self.ringEnd)
        return Circle(radius: radius * (0.24 + 0.76 * eased), opacity: shown * (1 - fade * fade))
    }

    /// The fainter ring inside, at about half the bright ring's radius, gone by frame 4.
    func innerRing(at time: Double) -> Circle {
        let outer = ring(at: time)
        let fade = Self.share(time, from: 2 * Self.frame, to: 4 * Self.frame)
        return Circle(radius: outer.radius * 0.52, opacity: outer.opacity > 0 ? 0.7 * (1 - fade) : 0)
    }

    /// The cyan haze filling the middle of the ring, fading out by frame 5.
    func center(at time: Double) -> Circle {
        let shown = Self.share(time, from: 0.5 * Self.frame, to: Self.frame)
        let fade = Self.share(time, from: Self.frame, to: 5 * Self.frame)
        return Circle(radius: radius * 0.45, opacity: shown * (1 - fade))
    }

    /// The glow on both sides of the ring: brighter and longer-lived than the line, so it lingers
    /// as a haze for two frames after the line has gone, spreading as it fades.
    func ringGlow(at time: Double) -> Circle {
        let shown = Self.share(time, from: 0.5 * Self.frame, to: Self.frame)
        let fade = Self.share(time, from: 4 * Self.frame, to: Self.glowEnd)
        return Circle(radius: ring(at: time).radius, opacity: shown * (1 - fade))
    }

    /// The ring's glow as a soft band: how far out it reaches, and where along that reach it is
    /// clear, half lit, fully lit, half lit and clear again, so it falls off softly on both sides.
    func glowBand(at time: Double) -> (outer: Double, locations: [Double]) {
        let middle = ringGlow(at: time).radius
        let half = glowWidth(at: time)
        let outer = middle + half
        let edges = [middle - half, middle - half * 0.45, middle, middle + half * 0.45, outer]
        return (outer, edges.map { min(max($0 / max(outer, 0.001), 0), 1) })
    }

    /// The band's opacity at each of `glowBand`'s locations.
    static let bandStops = [0, 0.55, 1, 0.55, 0.0]

    /// When the haze is gone.
    static let glowEnd = 9 * frame

    /// The ring's line: a thick bright donut as it leaves, thinning to about 2% of the radius.
    func ringLineWidth(at time: Double) -> Double {
        let grow = Self.share(time, from: Self.frame, to: 4 * Self.frame)
        return max(radius * 0.02, 1.5) * (1 + 3 * (1 - grow))
    }

    /// The glow's width: about a fifth of the radius, spreading as it fades.
    func glowWidth(at time: Double) -> Double {
        radius * 0.2 * (1 + 0.8 * Self.share(time, from: 3 * Self.frame, to: Self.glowEnd))
    }

    // MARK: Shards

    /// Where shard `shard` is at `time`, its turn in radians, and how solid it is.
    func place(_ shard: FrostShard, at time: Double) -> (center: CGPoint, turn: Double, opacity: Double) {
        let flight = Self.share(time, from: shard.leaves, to: 1)
        let eased = 1 - pow(1 - flight, 3)
        let distance = radius * (shard.from + (shard.to - shard.from) * eased)
        let center = CGPoint(x: cos(shard.angle) * distance, y: sin(shard.angle) * distance)
        let shown = Self.share(time, from: shard.leaves, to: shard.leaves + 0.5 * Self.frame)
        let fade = Self.share(time, from: 0.6, to: 1)
        return (center, shard.spin * eased, shown * (1 - fade))
    }

    /// Size of shard `shard`, in points.
    func side(of shard: FrostShard) -> Double { radius * shard.size }

    /// How far the burst reaches from the click, shards included.
    var reach: Double { radius * (FrostShard.farthest + FrostShard.largest) }

    /// `count` shards spread around the click, the same ones for the same seed.
    static func shards(count: Int, seed: UInt64) -> [FrostShard] {
        var random = SplitMix(seed: seed)
        let start = Double.random(in: 0..<(2 * .pi), using: &random)
        return (0..<count).map { index in
            FrostShard(index: index, of: count, start: start, using: &random)
        }
    }

    /// How far `time` is between `from` and `to`, from 0 to 1.
    static func share(_ time: Double, from: Double, to: Double) -> Double {
        min(max((time - from) / max(to - from, 0.0001), 0), 1)
    }

    struct Circle: Equatable {
        var radius: Double
        var opacity: Double
    }
}
