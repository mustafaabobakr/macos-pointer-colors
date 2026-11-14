import AppKit
import CoreImage

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
        let image = ZoomSharpener.enlarged(CIImage(cgImage: text), part: part, size: pixels, sharpening: upscaling.sharpening)
        return context.createCGImage(image, from: CGRect(origin: .zero, size: pixels), format: .RGBA8, colorSpace: colorSpace)
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
