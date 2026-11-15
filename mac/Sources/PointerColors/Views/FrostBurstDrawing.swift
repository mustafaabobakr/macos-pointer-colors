import SwiftUI

/// The Frost pulse drawn into a SwiftUI canvas for the Preferences previews, from the same
/// `FrostBurst` timeline and the same layers as the overlay's `FrostBurstLayers`.
struct FrostBurstDrawing {
    let burst: FrostBurst
    let colors: FrostColors
    let flash: Bool
    let shards: [FrostShard]

    init(style: HighlightStyle, seed: UInt64) {
        burst = style.frost
        colors = style.frostColors
        flash = style.frostFlash
        shards = FrostBurst.shards(count: style.frostShards, seed: seed)
    }

    /// Draws the burst at `point`, `time` through it as a share of the pulse length.
    func draw(at point: CGPoint, time: Double, in context: inout GraphicsContext) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        if flash { drawFlash(time, in: &local) }
        disc(colors.center, burst.center(at: time), stops: [0.75, 0.45, 0.12, 0], in: &local)
        drawRing(time, in: &local)
        shards.forEach { drawShard($0, time: time, in: &local) }
    }

    private func drawFlash(_ time: Double, in context: inout GraphicsContext) {
        disc(colors.flash, burst.flashGlow(at: time), stops: FrostColors.flashStops, in: &context)
        disc(colors.core, burst.flashCore(at: time), stops: [1, 1, 0.9, 0], in: &context)
    }

    private func drawRing(_ time: Double, in context: inout GraphicsContext) {
        let blur = burst.glowWidth(at: 0)
        drawGlowBand(time, in: &context)
        ring(colors.flash, burst.innerRing(at: time), lineWidth: burst.ringLineWidth(at: 1) * 0.8, blur: blur * 0.2, in: &context)
        ring(colors.core, burst.ring(at: time), lineWidth: burst.ringLineWidth(at: time), blur: blur * 0.15, in: &context)
    }

    private func drawShard(_ shard: FrostShard, time: Double, in context: inout GraphicsContext) {
        let spot = burst.place(shard, at: time)
        guard spot.opacity > 0 else { return }
        let side = burst.side(of: shard)
        context.drawLayer { layer in
            layer.opacity = spot.opacity
            layer.addFilter(.shadow(color: colors.glow.color.opacity(0.9), radius: max(side * 0.25, 1.5)))
            layer.translateBy(x: spot.center.x, y: spot.center.y)
            layer.rotate(by: .radians(spot.turn))
            layer.fill(Path(shard.outline(side: side)), with: .color(colors.shard.color))
            if let facet = shard.facet(side: side) {
                layer.fill(Path(facet), with: .color(colors.shardShade.color.opacity(0.85)))
            }
        }
    }

    /// The soft glow on both sides of the ring, as a radial gradient band.
    private func drawGlowBand(_ time: Double, in context: inout GraphicsContext) {
        let band = burst.glowBand(at: time)
        let opacity = burst.ringGlow(at: time).opacity * FrostColors.glowOpacity
        disc(colors.glow, FrostBurst.Circle(radius: band.outer, opacity: opacity), stops: FrostBurst.bandStops,
             locations: band.locations, in: &context)
    }

    /// A disc fading from `color` in the middle to clear at its edge, through `stops` opacities.
    private func disc(_ color: RGBA, _ circle: FrostBurst.Circle, stops: [Double], locations: [Double]? = nil,
                      in context: inout GraphicsContext) {
        guard circle.opacity > 0, circle.radius > 0 else { return }
        let spots = locations ?? FrostColors.locations(count: stops.count)
        let gradient = Gradient(stops: zip(stops, spots).map { opacity, location in
            .init(color: color.color.opacity(opacity * circle.opacity), location: location)
        })
        let rect = CGRect(x: -circle.radius, y: -circle.radius, width: circle.radius * 2, height: circle.radius * 2)
        context.fill(Path(ellipseIn: rect), with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: circle.radius))
    }

    private func ring(_ color: RGBA, _ circle: FrostBurst.Circle, lineWidth: Double, blur: Double,
                      in context: inout GraphicsContext) {
        guard circle.opacity > 0 else { return }
        let rect = CGRect(x: -circle.radius, y: -circle.radius, width: circle.radius * 2, height: circle.radius * 2)
        context.drawLayer { layer in
            layer.opacity = circle.opacity
            layer.addFilter(.shadow(color: colors.glow.color, radius: blur))
            layer.stroke(Path(ellipseIn: rect), with: .color(color.color), lineWidth: lineWidth)
        }
    }
}
