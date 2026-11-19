// IOSurface references are safe from any thread; the module just isn't annotated.
@preconcurrency import IOSurface
import Metal
import QuartzCore

/// Shows the part of a screen capture a zoom shows at the zoom's own pixel size, sharpened by
/// `SharpEnlarger`, in a Metal layer of its own.
///
/// Each picture shows in the same display frame as the lens moves or grows, so it always matches
/// where the lens is: the layer presents with the frame's other changes. The main thread only queues
/// the drawing on the graphics chip, well under a millisecond, and never waits for it to finish.
///
/// Colors pass through untouched: the layer has no color profile, so the window server takes its
/// pixels to be in the display's own colors, like the capture's.
@MainActor
final class ZoomSharpener {
    /// Sits over the capture, filling the zoom; hidden until it shows a picture.
    let layer = CAMetalLayer()
    /// Whether the layer shows a picture of the capture.
    private(set) var isShowing = false
    /// How many pictures it has drawn.
    private(set) var picturesDrawn = 0
    private let enlarger: SharpEnlarger
    /// The newest frame's surface, ready for the graphics chip, and which frame it is.
    private var source: (number: Int, texture: MTLTexture)?
    /// What the last picture was, to skip drawing the same one again.
    private var lastJob: Job?

    private struct Job: Equatable {
        let frame: Int
        let part: CGRect
        let size: CGSize
        let sharpening: Double
    }

    init?() {
        guard let enlarger = SharpEnlarger.shared else { return nil }
        self.enlarger = enlarger
        layer.device = enlarger.device
        layer.pixelFormat = .bgra8Unorm
        layer.colorspace = nil
        // The sharpening writes straight into the layer's pictures.
        layer.framebufferOnly = false
        layer.isOpaque = true
        layer.presentsWithTransaction = true
        layer.isHidden = true
    }

    /// Shows `part` (units of the capture, from its top left) of `frame` drawn at `size` pixels, with
    /// the current Core Animation transaction. `number` counts the capture's frames, so a new one is drawn.
    func show(_ frame: HeldFrame, number: Int, part: CGRect, size: CGSize, sharpening: Double) {
        let size = CGSize(width: max(size.width.rounded(), 1), height: max(size.height.rounded(), 1))
        let job = Job(frame: number, part: part, size: size, sharpening: sharpening)
        guard job != lastJob else { return }
        if layer.drawableSize != size { layer.drawableSize = size }
        guard let texture = texture(of: frame, number: number), let drawable = layer.nextDrawable(),
              let buffer = enlarger.queue.makeCommandBuffer() else { return }
        lastJob = job
        enlarger.encode(texture, part: part, sharpening: sharpening, into: drawable.texture, on: buffer)
        // The frame stays held while it's read, so the capture can't paint over it meanwhile.
        buffer.addCompletedHandler { _ in withExtendedLifetime(frame) {} }
        buffer.commit()
        buffer.waitUntilScheduled()
        drawable.present()
        layer.isHidden = false
        isShowing = true
        picturesDrawn += 1
    }

    /// Hides the layer until the next picture, and forgets the frames it drew from.
    func reset() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.isHidden = true
        CATransaction.commit()
        isShowing = false
        lastJob = nil
        source = nil
    }

    private func texture(of frame: HeldFrame, number: Int) -> MTLTexture? {
        if let source, source.number == number { return source.texture }
        let surface = frame.surface
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: IOSurfaceGetWidth(surface),
                                                                  height: IOSurfaceGetHeight(surface), mipmapped: false)
        descriptor.usage = .shaderRead
        guard let texture = enlarger.device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else { return nil }
        source = (number, texture)
        return texture
    }
}
