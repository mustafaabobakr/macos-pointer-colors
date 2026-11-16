import SwiftUI

/// The Bokeh pulse drawn into a SwiftUI canvas for the Preferences previews, from the same
/// `BokehBurst` timeline and the same parts as the overlay's `BokehBurstLayers`.
struct BokehBurstDrawing {
    let burst: BokehBurst
    let colors: BokehColors
    let showsFrame: Bool
    let tiles: [BokehTile]

    init(style: HighlightStyle, seed: UInt64) {
        burst = style.bokeh
        colors = style.bokehColors
        showsFrame = style.bokehFrame
        tiles = BokehBurst.tiles(count: style.bokehTiles, seed: seed)
    }

    /// Draws the burst at `point`, `time` through it as a share of the pulse length.
    func draw(at point: CGPoint, time: Double, in context: inout GraphicsContext) {
        var local = context
        local.translateBy(x: point.x, y: point.y)
        if showsFrame {
            var frame = burst.glowFrame(at: time)
            frame.opacity *= BokehColors.frameOpacity / BokehColors.lineOpacity
            square(frame, at: .zero, color: colors.light, lineWidth: burst.frameLineWidth, in: &local)
        }
        for tile in tiles {
            let spot = burst.place(tile, at: time)
            let color = tile.isWarm ? colors.warm : colors.light
            square(spot.square, at: spot.center, color: color, lineWidth: tile.isFilled ? nil : burst.lineWidth, in: &local)
        }
        square(burst.middle(at: time), at: .zero, color: colors.light, lineWidth: burst.lineWidth, in: &local)
    }

    /// One rounded square centred on `center`: outlined `lineWidth` wide, or filled when that's nil.
    private func square(_ square: BokehBurst.Square, at center: CGPoint, color: RGBA, lineWidth: Double?,
                        in context: inout GraphicsContext) {
        guard square.opacity > 0, square.side > 0 else { return }
        let rect = CGRect(x: center.x - square.side / 2, y: center.y - square.side / 2, width: square.side, height: square.side)
        let shape = Path(roundedRect: rect, cornerRadius: square.cornerRadius)
        context.drawLayer { layer in
            if square.blur > 0 { layer.addFilter(.blur(radius: square.blur)) }
            guard let lineWidth else {
                layer.fill(shape, with: .color(color.color.opacity(square.opacity * BokehColors.fillOpacity)))
                return
            }
            layer.stroke(shape, with: .color(color.color.opacity(square.opacity * BokehColors.lineOpacity)), lineWidth: lineWidth)
        }
    }
}
