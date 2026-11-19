import AppKit
import CoreImage
import Metal

/// A line of text drawn the way the screen draws it, then enlarged by a ZoomUpscaling the same way
/// the zoom does, so the Advanced cards show each choice at real size and the real zoom amount.
@MainActor
enum ZoomUpscalingSample {
    private static let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    /// The picture for a frame of `size` points on a display of `scale` pixels per point.
    static func picture(_ upscaling: ZoomUpscaling, size: CGSize, amount: Double, scale: CGFloat, dark: Bool) -> CGImage? {
        let pixels = CGSize(width: max((size.width * scale).rounded(), 1), height: max((size.height * scale).rounded(), 1))
        let shown = CGSize(width: pixels.width / amount, height: pixels.height / amount)
        let screen = CGSize(width: shown.width.rounded(.up), height: shown.height.rounded(.up))
        guard let text = screenText(pixels: screen, scale: scale, dark: dark) else { return nil }
        let part = CGRect(x: 0, y: 0, width: shown.width / screen.width, height: shown.height / screen.height)
        guard let sharpening = upscaling.sharpening else { return smooth(text, part: part, size: pixels) }
        // Without a graphics chip that can sharpen, the zoom shows smoothed, and so does this.
        return sharp(text, part: part, size: pixels, sharpening: sharpening) ?? smooth(text, part: part, size: pixels)
    }

    /// `part` of `text` (units of it, from its top left) stretched to `size` pixels with the plain
    /// blending between pixels the display does for Smooth.
    private static func smooth(_ text: CGImage, part: CGRect, size: CGSize) -> CGImage? {
        let source = CIImage(cgImage: text)
        let width = source.extent.width, height = source.extent.height
        // Core Image counts from the bottom left.
        let crop = CGRect(x: part.minX * width, y: (1 - part.maxY) * height, width: part.width * width, height: part.height * height)
        let image = source.clampedToExtent()
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: size.width / crop.width, y: size.height / crop.height))
            .cropped(to: CGRect(origin: .zero, size: size))
        return context.createCGImage(image, from: CGRect(origin: .zero, size: size), format: .RGBA8, colorSpace: colorSpace)
    }

    /// `part` of `text` enlarged to `size` pixels by the zoom's own `SharpEnlarger`.
    private static func sharp(_ text: CGImage, part: CGRect, size: CGSize, sharpening: Double) -> CGImage? {
        guard let enlarger = SharpEnlarger.shared, let buffer = enlarger.queue.makeCommandBuffer(),
              let source = SurfaceBitmap(width: text.width, height: text.height, device: enlarger.device),
              let target = SurfaceBitmap(width: Int(size.width), height: Int(size.height), device: enlarger.device) else { return nil }
        source.draw(text)
        enlarger.encode(source.texture, part: part, sharpening: sharpening, into: target.texture, on: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        return target.image()
    }

    /// Body text on a window background, `pixels` big, as a display of `scale` shows it.
    private static func screenText(pixels: CGSize, scale: CGFloat, dark: Bool) -> CGImage? {
        guard let bitmap = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                                     bytesPerRow: 0, space: colorSpace,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        bitmap.setFillColor(CGColor(gray: dark ? 0.12 : 1, alpha: 1))
        bitmap.fill(CGRect(origin: .zero, size: pixels))
        bitmap.scaleBy(x: scale, y: scale)
        let height = pixels.height / scale
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
        let text = NSAttributedString(string: String(localized: "Zoom in to read small text clearly."), attributes: [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor(white: dark ? 0.9 : 0.1, alpha: 1),
        ])
        text.draw(at: CGPoint(x: 3, y: (height - text.size().height) / 2))
        NSGraphicsContext.current = previous
        return bitmap.makeImage()
    }
}

/// A BGRA picture both the processor and the graphics chip can reach, as the zoom's capture is.
private struct SurfaceBitmap {
    let surface: IOSurfaceRef
    let texture: MTLTexture
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init?(width: Int, height: Int, device: MTLDevice) {
        guard let surface = IOSurfaceCreate([kIOSurfaceWidth: width, kIOSurfaceHeight: height, kIOSurfaceBytesPerElement: 4,
                                             kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA] as CFDictionary) else { return nil }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else { return nil }
        self.surface = surface
        self.texture = texture
    }

    func draw(_ image: CGImage) {
        withContext { $0.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)) }
    }

    func image() -> CGImage? {
        var image: CGImage?
        withContext { image = $0.makeImage() }
        return image
    }

    private func withContext(_ body: (CGContext) -> Void) {
        IOSurfaceLock(surface, [], nil)
        defer { IOSurfaceUnlock(surface, [], nil) }
        let info = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(data: IOSurfaceGetBaseAddress(surface), width: IOSurfaceGetWidth(surface),
                                      height: IOSurfaceGetHeight(surface), bitsPerComponent: 8,
                                      bytesPerRow: IOSurfaceGetBytesPerRow(surface), space: Self.colorSpace, bitmapInfo: info) else { return }
        body(context)
    }
}
