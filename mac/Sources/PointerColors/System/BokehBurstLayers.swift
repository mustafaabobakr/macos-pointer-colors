import AppKit
import CoreImage
import QuartzCore

/// The Bokeh pulse as Core Animation layers: every part's keyframes are sampled from `BokehBurst`,
/// the same timeline the Preferences preview draws, and handed to Core Animation to play. The
/// softness comes from a Core Image blur on each layer, so the hosting view needs
/// `layerUsesCoreImageFilters`.
@MainActor
struct BokehBurstLayers {
    /// Keyframes per pulse: two for each of the clip's 13 frames.
    private static let samples = 26
    /// The blur filter's name on each layer, for animating its radius.
    private static let blurKey = "filters.blur.inputRadius"

    let burst: BokehBurst
    let duration: Double
    let shapes: [BokehShape]?
    let palette: BokehPalette
    private let begin = CACurrentMediaTime()

    init(style: HighlightStyle) {
        burst = style.bokeh
        duration = style.pulseDuration
        shapes = style.bokehShapes
        palette = style.bokehPalette
    }

    /// Adds one burst at `point` to `parent`, and removes it once it has played.
    func add(to parent: CALayer, at point: CGPoint) {
        let burstLayer = CALayer()
        burstLayer.position = point
        CATransaction.begin()
        CATransaction.setCompletionBlock { burstLayer.removeFromSuperlayer() }
        BokehBurst.tiles(seed: UInt64.random(in: .min ... .max), shapes: shapes).forEach { addTile($0, to: burstLayer) }
        addMiddle(to: burstLayer)
        parent.addSublayer(burstLayer)
        CATransaction.commit()
    }

    // MARK: Parts

    /// The square that flashes large and shrinks into the pointer: a soft halo under its line.
    private func addMiddle(to burstLayer: CALayer) {
        let glow = middlePiece(width: BokehBurst.glowWidth, opacity: BokehBurst.glowOpacity * burst.haloStrength) {
            burst.middleGlow(at: $0)
        }
        let line = middlePiece(width: 1, opacity: 1) { burst.middle(at: $0).blur }
        [glow, line].forEach { burstLayer.addSublayer($0.shape) }
    }

    /// One layer of the middle square, its line `width` times as wide as the line, `opacity` as
    /// solid, and blurred by `blur` at each moment.
    private func middlePiece(width: Double, opacity: Double, blur: @escaping (Double) -> Double) -> PieceLayer {
        let piece = PieceLayer(room: burst.middle(at: 0).side, blur: blur(0), lineWidth: burst.middleLineWidth(at: 0) * width)
        piece.shape.strokeColor = palette.middle.cgColor(alpha: 1)
        piece.setBlur(blur(0))
        play(piece.shape, "path") { piece.path(side: burst.middle(at: $0).side) }
        play(piece.shape, "lineWidth") { burst.middleLineWidth(at: $0) * width }
        play(piece.shape, "opacity") { burst.middle(at: $0).opacity * opacity }
        play(piece.shape, Self.blurKey, value: blur)
        return piece
    }

    /// A filled square, or an outlined one over its soft halo.
    private func addTile(_ tile: BokehTile, to burstLayer: CALayer) {
        guard !tile.isFilled else {
            return burstLayer.addSublayer(tilePiece(tile, fill: palette.square(shade: tile.shade)).shape)
        }
        let color = palette.square(shade: tile.shade)
        let glow = tilePiece(tile, stroke: color, width: BokehBurst.outlineGlowWidth, extraBlur: burst.outlineGlowBlur,
                             opacity: BokehBurst.outlineGlowOpacity * burst.haloStrength)
        [glow, tilePiece(tile, stroke: color)].forEach { burstLayer.addSublayer($0.shape) }
    }

    /// One layer of flying square `tile`: filled with `fill`, or outlined in `stroke` with its line
    /// `width` times as wide, `extraBlur` softer and `opacity` as solid.
    private func tilePiece(_ tile: BokehTile, fill: RGBA? = nil, stroke: RGBA? = nil, width: Double = 1,
                           extraBlur: Double = 0, opacity: Double = 1) -> PieceLayer {
        let first = burst.place(tile, at: 0).square
        let piece = PieceLayer(room: first.side, blur: first.blur + extraBlur, lineWidth: burst.lineWidth * width)
        piece.shape.fillColor = fill?.cgColor(alpha: 1)
        piece.shape.strokeColor = stroke?.cgColor(alpha: 1)
        piece.setBlur(first.blur + extraBlur)
        play(piece.shape, "path") { piece.path(side: burst.place(tile, at: $0).square.side) }
        play(piece.shape, "position") { NSValue(point: burst.place(tile, at: $0).center) }
        play(piece.shape, "opacity") { burst.place(tile, at: $0).square.opacity * opacity }
        play(piece.shape, Self.blurKey) { burst.place(tile, at: $0).square.blur + extraBlur }
        return piece
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

/// One rounded square's layer, with room around the square for its blur to spread into, since a
/// layer's filter draws only inside its bounds.
@MainActor
private struct PieceLayer {
    let shape = CAShapeLayer()
    private let middle: Double

    /// Room for a square up to `room` points wide, blurred by up to `blur`, with a `lineWidth` line.
    init(room: Double, blur: Double, lineWidth: Double) {
        let width = room + lineWidth + blur * 6
        middle = width / 2
        shape.bounds = CGRect(x: 0, y: 0, width: width, height: width)
        shape.fillColor = nil
        shape.lineWidth = lineWidth
        shape.opacity = 0
    }

    /// A rounded square `side` points wide, in the middle of the layer.
    func path(side: Double) -> CGPath {
        let side = max(side, 0.1)
        let radius = side * BokehBurst.Square.cornerShare
        let rect = CGRect(x: middle - side / 2, y: middle - side / 2, width: side, height: side)
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    /// Gives the layer a Gaussian blur named "blur", starting at `radius`.
    func setBlur(_ radius: Double) {
        guard let blur = CIFilter(name: "CIGaussianBlur") else { return }
        blur.name = "blur"
        blur.setValue(radius, forKey: kCIInputRadiusKey)
        shape.filters = [blur]
    }
}
