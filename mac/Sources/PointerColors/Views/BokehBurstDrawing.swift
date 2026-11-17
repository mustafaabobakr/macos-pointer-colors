import SwiftUI

/// The Bokeh pulse drawn into a SwiftUI canvas for the Preferences previews, from the same
/// `BokehBurst` timeline and the same parts as the overlay's `BokehBurstLayers`.
struct BokehBurstDrawing {
    let burst: BokehBurst
    let tiles: [BokehTile]
    let palette: BokehPalette

    init(style: HighlightStyle, seed: UInt64) {
        burst = style.bokeh
        tiles = BokehBurst.tiles(seed: seed, shapes: style.bokehShapes)
        palette = style.bokehPalette
    }

    /// Draws the burst at `point`, `time` through it as a share of the pulse length.
    func draw(at point: CGPoint, time: Double, in context: inout GraphicsContext) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        for tile in tiles {
            let spot = burst.place(tile, at: time)
            drawTile(tile, at: spot, in: &local)
        }
        drawMiddle(time, in: &local)
    }

    /// A filled square, or an outlined one over its soft halo.
    private func drawTile(_ tile: BokehTile, at spot: (center: CGPoint, square: BokehBurst.Square),
                          in context: inout GraphicsContext) {
        guard !tile.isFilled else {
            return square(spot.square, at: spot.center, color: palette.square(shade: tile.shade), opacity: 1,
                          lineWidth: nil, in: &context)
        }
        let color = palette.square(shade: tile.shade)
        var glow = spot.square
        glow.blur += burst.outlineGlowBlur
        square(glow, at: spot.center, color: color, opacity: BokehBurst.outlineGlowOpacity * burst.haloStrength,
               lineWidth: burst.lineWidth * BokehBurst.outlineGlowWidth, in: &context)
        square(spot.square, at: spot.center, color: color, opacity: 1, lineWidth: burst.lineWidth, in: &context)
    }

    /// The middle square's soft halo, then its line over it.
    private func drawMiddle(_ time: Double, in context: inout GraphicsContext) {
        let line = burst.middle(at: time)
        let width = burst.middleLineWidth(at: time)
        var glow = line
        glow.blur = burst.middleGlow(at: time)
        square(glow, at: .zero, color: palette.middle, opacity: BokehBurst.glowOpacity * burst.haloStrength,
               lineWidth: width * BokehBurst.glowWidth, in: &context)
        square(line, at: .zero, color: palette.middle, opacity: 1, lineWidth: width, in: &context)
    }

    /// One rounded square centred on `center`: outlined `lineWidth` wide, or filled when that's nil.
    private func square(_ square: BokehBurst.Square, at center: CGPoint, color: RGBA, opacity: Double,
                        lineWidth: Double?, in context: inout GraphicsContext) {
        guard square.opacity > 0, square.side > 0 else { return }
        let rect = CGRect(x: center.x - square.side / 2, y: center.y - square.side / 2, width: square.side, height: square.side)
        let shape = Path(roundedRect: rect, cornerRadius: square.cornerRadius)
        let shading = GraphicsContext.Shading.color(color.color.opacity(square.opacity * opacity))
        context.drawLayer { layer in
            if square.blur > 0 { layer.addFilter(.blur(radius: square.blur)) }
            guard let lineWidth else { return layer.fill(shape, with: shading) }
            layer.stroke(shape, with: shading, lineWidth: lineWidth)
        }
    }
}
