import CoreGraphics
import Metal
import MetalPerformanceShaders

/// Enlarges part of a picture on the graphics chip: Lanczos scaling, then an unsharp mask, so edges
/// stay crisper than the display's plain smoothing. Shared by the zoom and its Preferences preview,
/// so the preview shows exactly what the zoom draws.
///
/// Colors pass through untouched: the kernels work on the pixels' own values, with no color management.
@MainActor
final class SharpEnlarger {
    static let shared = SharpEnlarger()

    let device: MTLDevice
    let queue: MTLCommandQueue
    private let lanczos: MPSImageLanczosScale
    private let subtract: MPSImageSubtract
    private var blur: MPSImageGaussianBlur?

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(), MPSSupportsMTLDevice(device),
              let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.queue = queue
        lanczos = MPSImageLanczosScale(device: device)
        // Past the capture's edges, its edge pixels repeat rather than black.
        lanczos.edgeMode = .clamp
        subtract = MPSImageSubtract(device: device)
    }

    /// Encodes `part` of `source` (units of it, from its top left) enlarged to fill `target`, with an
    /// unsharp mask of `sharpening`: the picture plus `sharpening` times its difference from a blur of it.
    func encode(_ source: MTLTexture, part: CGRect, sharpening: Double, into target: MTLTexture, on buffer: MTLCommandBuffer) {
        let width = Double(source.width), height = Double(source.height)
        let crop = CGRect(x: part.minX * width, y: part.minY * height,
                          width: max(part.width * width, 1), height: max(part.height * height, 1))
        let scaleX = Double(target.width) / crop.width, scaleY = Double(target.height) / crop.height
        var transform = MPSScaleTransform(scaleX: scaleX, scaleY: scaleY,
                                          translateX: -crop.minX * scaleX, translateY: -crop.minY * scaleY)
        let scaled = temporary(like: target, on: buffer, reads: 2)
        let blurred = temporary(like: target, on: buffer, reads: 1)
        withUnsafePointer(to: &transform) { transform in
            lanczos.scaleTransform = transform
            lanczos.encode(commandBuffer: buffer, sourceImage: MPSImage(texture: source, featureChannels: 4), destinationImage: scaled)
            lanczos.scaleTransform = nil
        }
        blurKernel(sigma: Float(max(scaleY * 0.8, 1))).encode(commandBuffer: buffer, sourceImage: scaled, destinationImage: blurred)
        subtract.primaryScale = Float(1 + sharpening)
        subtract.secondaryScale = Float(sharpening)
        subtract.encode(commandBuffer: buffer, primaryImage: scaled, secondaryImage: blurred,
                        destinationImage: MPSImage(texture: target, featureChannels: 4))
    }

    /// A picture the size of `target` that lives only while `buffer` runs, read `reads` times.
    private func temporary(like target: MTLTexture, on buffer: MTLCommandBuffer, reads: Int) -> MPSTemporaryImage {
        let descriptor = MPSImageDescriptor(channelFormat: .unorm8, width: target.width, height: target.height, featureChannels: 4)
        let image = MPSTemporaryImage(commandBuffer: buffer, imageDescriptor: descriptor)
        image.readCount = reads
        return image
    }

    /// The blur for `sigma`, made again only when it changes, as it does while the zoom grows.
    private func blurKernel(sigma: Float) -> MPSImageGaussianBlur {
        if let blur, blur.sigma == sigma { return blur }
        let blur = MPSImageGaussianBlur(device: device, sigma: sigma)
        blur.edgeMode = .clamp
        self.blur = blur
        return blur
    }
}
