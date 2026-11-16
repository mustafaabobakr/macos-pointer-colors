import AppKit
import CoreImage
import QuartzCore

/// The Bokeh pulse as Core Animation layers: every part's keyframes are sampled from `BokehBurst`,
/// the same timeline the Preferences preview draws, and handed to Core Animation to play. The
/// squares come into focus through a Core Image blur on each layer, so the hosting view needs
/// `layerUsesCoreImageFilters`.
@MainActor
struct BokehBurstLayers {
    /// Keyframes per pulse: enough that the sampled curves look smooth at 120 Hz.
    private static let samples = 32
    /// The blur filter's name on each layer, for animating its radius.
    private static let blurKey = "filters.blur.inputRadius"

    let burst: BokehBurst
    let colors: BokehColors
    let duration: Double
    let showsFrame: Bool
    let tileCount: Int
    private let begin = CACurrentMediaTime()

    init(style: HighlightStyle) {
        burst = style.bokeh
        colors = style.bokehColors
        duration = style.pulseDuration
        showsFrame = style.bokehFrame
        tileCount = style.bokehTiles
    }

    /// Adds one burst at `point` to `parent`, and removes it once it has played.
    func add(to parent: CALayer, at point: CGPoint) {
        let burstLayer = CALayer()
        burstLayer.position = point
        CATransaction.begin()
        CATransaction.setCompletionBlock { burstLayer.removeFromSuperlayer() }
        if showsFrame { addGlowFrame(to: burstLayer) }
        let seed = UInt64.random(in: .min ... .max)
        BokehBurst.tiles(count: tileCount, seed: seed).forEach { addTile($0, to: burstLayer) }
        addMiddle(to: burstLayer)
        parent.addSublayer(burstLayer)
        CATransaction.commit()
    }

    // MARK: Parts

    private func addGlowFrame(to burstLayer: CALayer) {
        let piece = PieceLayer(room: burst.glowFrame(at: 0).side, blur: burst.frameBlur, lineWidth: burst.frameLineWidth)
        piece.shape.strokeColor = colors.light.cgColor(alpha: 1)
        piece.setBlur(burst.frameBlur)
        play(piece.shape, "path") { piece.path(side: burst.glowFrame(at: $0).side) }
        play(piece.shape, "opacity") { burst.glowFrame(at: $0).opacity * BokehColors.frameOpacity }
        burstLayer.addSublayer(piece.shape)
    }

    private func addMiddle(to burstLayer: CALayer) {
        let piece = PieceLayer(room: burst.base, blur: burst.maxBlur, lineWidth: burst.lineWidth)
        piece.shape.strokeColor = colors.light.cgColor(alpha: 1)
        play(piece.shape, "path") { piece.path(side: burst.middle(at: $0).side) }
        play(piece.shape, "opacity") { burst.middle(at: $0).opacity * BokehColors.lineOpacity }
        playBlur(on: piece) { burst.middle(at: $0).blur }
        burstLayer.addSublayer(piece.shape)
    }

    private func addTile(_ tile: BokehTile, to burstLayer: CALayer) {
        let side = burst.base * tile.size
        let piece = PieceLayer(room: side, blur: burst.maxBlur, lineWidth: burst.lineWidth)
        let color = (tile.isWarm ? colors.warm : colors.light).cgColor(alpha: 1)
        piece.shape.path = piece.path(side: side)
        if tile.isFilled { piece.shape.fillColor = color } else { piece.shape.strokeColor = color }
        let strength = tile.isFilled ? BokehColors.fillOpacity : BokehColors.lineOpacity
        play(piece.shape, "position") { NSValue(point: burst.place(tile, at: $0).center) }
        play(piece.shape, "opacity") { burst.place(tile, at: $0).square.opacity * strength }
        playBlur(on: piece) { burst.place(tile, at: $0).square.blur }
        burstLayer.addSublayer(piece.shape)
    }

    // MARK: Animation

    /// Plays the blur's radius, when the squares come into focus; sharp squares have no filter.
    private func playBlur(on piece: PieceLayer, radius: (Double) -> Double) {
        guard burst.focus else { return }
        piece.setBlur(radius(0))
        play(piece.shape, Self.blurKey) { radius($0) }
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
