import AppKit
import QuartzCore

/// The Frost pulse as Core Animation layers: every part's keyframes are sampled from `FrostBurst`,
/// the same timeline the Preferences preview draws, and handed to Core Animation to play.
@MainActor
struct FrostBurstLayers {
    /// Keyframes per pulse: enough that the sampled curves look smooth at 120 Hz.
    private static let samples = 32

    let burst: FrostBurst
    let colors: FrostColors
    let duration: Double
    private let begin = CACurrentMediaTime()

    init(style: HighlightStyle) {
        burst = style.frost
        colors = style.frostColors
        duration = style.pulseDuration
    }

    /// Adds one burst at `point` to `parent`, and removes it once it has played.
    func add(to parent: CALayer, at point: CGPoint, flash: Bool, shards: Int) {
        let burstLayer = CALayer()
        burstLayer.position = point
        CATransaction.begin()
        CATransaction.setCompletionBlock { burstLayer.removeFromSuperlayer() }
        if flash { addFlash(to: burstLayer) }
        addCenter(to: burstLayer)
        addRing(to: burstLayer)
        let seed = UInt64.random(in: .min ... .max)
        FrostBurst.shards(count: shards, seed: seed).forEach { addShard($0, to: burstLayer) }
        parent.addSublayer(burstLayer)
        CATransaction.commit()
    }

    // MARK: Parts

    private func addFlash(to burstLayer: CALayer) {
        let widest = burst.radius * FrostBurst.flashReach
        let glow = glowDisc(colors.flash, radius: widest, stops: FrostColors.flashStops)
        play(glow, "transform.scale") { burst.flashGlow(at: $0).radius / widest }
        play(glow, "opacity") { burst.flashGlow(at: $0).opacity }
        let coreSide = burst.radius * 0.43
        let core = glowDisc(colors.core, radius: coreSide, stops: [1, 1, 0.9, 0])
        play(core, "transform.scale") { burst.flashCore(at: $0).radius / coreSide }
        play(core, "opacity") { burst.flashCore(at: $0).opacity }
        burstLayer.addSublayer(glow)
        burstLayer.addSublayer(core)
    }

    private func addCenter(to burstLayer: CALayer) {
        let center = glowDisc(colors.center, radius: burst.radius * 0.45, stops: [0.75, 0.45, 0.12, 0])
        play(center, "opacity") { burst.center(at: $0).opacity }
        burstLayer.addSublayer(center)
    }

    /// The glow on both sides of the ring, the fainter inner ring, then the bright line on top.
    private func addRing(to burstLayer: CALayer) {
        let blur = burst.glowWidth(at: 0)
        let glow = glowDisc(colors.glow, radius: burst.radius, stops: FrostBurst.bandStops)
        play(glow, "bounds") { NSValue(rect: square(burst.glowBand(at: $0).outer)) }
        play(glow, "locations") { burst.glowBand(at: $0).locations }
        play(glow, "opacity") { burst.ringGlow(at: $0).opacity * FrostColors.glowOpacity }
        let inner = ringLayer(colors.flash, lineWidth: burst.ringLineWidth(at: 1) * 0.8, blur: blur * 0.2)
        let line = ringLayer(colors.core, lineWidth: burst.ringLineWidth(at: 1), blur: blur * 0.15)
        play(inner, "path") { circle(burst.innerRing(at: $0).radius) }
        play(inner, "opacity") { burst.innerRing(at: $0).opacity }
        play(line, "path") { circle(burst.ring(at: $0).radius) }
        play(line, "lineWidth") { burst.ringLineWidth(at: $0) }
        play(line, "opacity") { burst.ring(at: $0).opacity }
        [glow, inner, line].forEach(burstLayer.addSublayer)
    }

    private func addShard(_ shard: FrostShard, to burstLayer: CALayer) {
        let piece = shardLayer(shard, side: burst.side(of: shard))
        play(piece, "position") { NSValue(point: burst.place(shard, at: $0).center) }
        play(piece, "transform.rotation.z") { burst.place(shard, at: $0).turn }
        play(piece, "opacity") { burst.place(shard, at: $0).opacity }
        burstLayer.addSublayer(piece)
    }

    // MARK: Layers

    /// A disc fading from `color` in the middle to clear at `radius`, through `stops` opacities
    /// spread evenly from the middle out, unless the caller animates its locations.
    private func glowDisc(_ color: RGBA, radius: Double, stops: [Double]) -> CAGradientLayer {
        let disc = CAGradientLayer()
        disc.type = .radial
        disc.bounds = square(radius)
        disc.colors = stops.map { color.cgColor(alpha: $0) }
        disc.locations = FrostColors.locations(count: stops.count).map { NSNumber(value: $0) }
        disc.startPoint = CGPoint(x: 0.5, y: 0.5)
        disc.endPoint = CGPoint(x: 1, y: 1)
        disc.opacity = 0
        return disc
    }

    /// A shard's lit outline with its shaded facet over it, glowing; a sparkle is a dot.
    private func shardLayer(_ shard: FrostShard, side: Double) -> CAShapeLayer {
        let piece = CAShapeLayer()
        piece.path = shard.outline(side: side)
        piece.fillColor = colors.shard.cgColor(alpha: 1)
        piece.shadowColor = colors.glow.cgColor(alpha: 1)
        piece.shadowOpacity = 0.9
        piece.shadowRadius = max(side * 0.25, 1.5)
        piece.shadowOffset = .zero
        piece.opacity = 0
        if let facet = shard.facet(side: side) {
            let shade = CAShapeLayer()
            shade.path = facet
            shade.fillColor = colors.shardShade.cgColor(alpha: 0.85)
            piece.addSublayer(shade)
        }
        return piece
    }

    private func ringLayer(_ color: RGBA, lineWidth: Double, blur: Double) -> CAShapeLayer {
        let ring = CAShapeLayer()
        ring.fillColor = nil
        ring.strokeColor = color.cgColor(alpha: 1)
        ring.lineWidth = lineWidth
        ring.shadowColor = colors.glow.cgColor(alpha: 1)
        ring.shadowOpacity = 1
        ring.shadowRadius = blur
        ring.shadowOffset = .zero
        ring.opacity = 0
        return ring
    }

    private func square(_ radius: Double) -> CGRect {
        CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
    }

    private func circle(_ radius: Double) -> CGPath {
        CGPath(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2), transform: nil)
    }

    /// Plays `key` on `layer` through the burst, its value at each moment from `value`.
    private func play(_ layer: CALayer, _ key: String, value: (Double) -> Any) {
        let steps = (0...Self.samples).map { Double($0) / Double(Self.samples) }
        let frames = CAKeyframeAnimation(keyPath: key)
        frames.values = steps.map(value)
        frames.keyTimes = steps.map { NSNumber(value: $0) }
        frames.duration = duration
        frames.beginTime = begin
        frames.fillMode = .both
        frames.isRemovedOnCompletion = false
        layer.add(frames, forKey: key)
    }
}
