import CoreImage
import CoreVideo
import Metal

/// Draws the part of a screen capture a zoom shows at the zoom's own pixel size, with Lanczos
/// scaling and an unsharp mask, so edges stay crisper than the display's plain smoothing.
/// Colors pass through untouched: no color management, as the capture is already in the
/// display's colors.
@MainActor
final class ZoomSharpener {
    private let context: CIContext
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    /// What the last picture was drawn from, to skip drawing the same one again.
    private var lastJob: Job?
    private var lastPicture: IOSurfaceRef?
    /// The last few pictures stay held, so the pool never hands back one still on screen.
    private var recent: [CVPixelBuffer] = []

    private struct Job: Equatable {
        let frame: Int
        let part: CGRect
        let size: CGSize
        let sharpening: Double
    }

    init() {
        let options: [CIContextOption: Any] = [.workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .cacheIntermediates: false]
        context = MTLCreateSystemDefaultDevice().map { CIContext(mtlDevice: $0, options: options) } ?? CIContext(options: options)
    }

    /// The picture of `part` (units of the capture, from its top left) of `surface` drawn at `size`
    /// pixels. `frame` counts the capture's frames, so a new one is drawn again.
    func picture(of surface: IOSurfaceRef, frame: Int, part: CGRect, size: CGSize, sharpening: Double) -> IOSurfaceRef? {
        let size = CGSize(width: max(size.width.rounded(), 1), height: max(size.height.rounded(), 1))
        let job = Job(frame: frame, part: part, size: size, sharpening: sharpening)
        if job == lastJob, let lastPicture { return lastPicture }
        guard let buffer = makeBuffer(size), let output = CVPixelBufferGetIOSurface(buffer)?.takeUnretainedValue() else { return nil }
        context.render(Self.enlarged(CIImage(ioSurface: surface), part: part, size: size, sharpening: sharpening), to: buffer,
                       bounds: CGRect(origin: .zero, size: size), colorSpace: nil)
        lastJob = job
        lastPicture = output
        recent = Array((recent + [buffer]).suffix(3))
        return output
    }

    func reset() {
        lastJob = nil
        lastPicture = nil
        recent = []
    }

    /// `part` of `source` (units of it, from its top left) enlarged to `size` pixels: Lanczos and an
    /// unsharp mask of `sharpening`, or with nil, the plain blending between pixels the display does
    /// for Smooth.
    nonisolated static func enlarged(_ source: CIImage, part: CGRect, size: CGSize, sharpening: Double?) -> CIImage {
        let width = source.extent.width, height = source.extent.height
        // Core Image counts from the bottom left.
        let crop = CGRect(x: part.minX * width, y: (1 - part.maxY) * height,
                          width: max(part.width * width, 1), height: max(part.height * height, 1))
        let scale = size.height / crop.height
        let aspect = (size.width / crop.width) / scale
        let moved = source.clampedToExtent().transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        guard let sharpening else {
            return moved.transformed(by: CGAffineTransform(scaleX: scale * aspect, y: scale))
                .cropped(to: CGRect(origin: .zero, size: size))
        }
        let scaled = moved.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale, kCIInputAspectRatioKey: aspect])
        let sharpened = scaled.applyingFilter("CIUnsharpMask", parameters: [
            kCIInputRadiusKey: max(scale * 0.8, 1), kCIInputIntensityKey: sharpening,
        ])
        return sharpened.cropped(to: CGRect(origin: .zero, size: size))
    }

    private func makeBuffer(_ size: CGSize) -> CVPixelBuffer? {
        if size != poolSize { pool = Self.makePool(size); poolSize = size }
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        return buffer
    }

    private static func makePool(_ size: CGSize) -> CVPixelBufferPool? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: Int(size.width), kCVPixelBufferHeightKey: Int(size.height),
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true,
        ]
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, [kCVPixelBufferPoolMinimumBufferCountKey: 4] as CFDictionary, attributes as CFDictionary, &pool)
        return pool
    }
}
