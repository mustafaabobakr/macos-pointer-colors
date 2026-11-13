import CoreMedia
import CoreVideo
import ScreenCaptureKit

/// Hands each complete frame of a screen capture to the main actor as an IOSurface.
final class ZoomStreamOutput: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "PointerColors.smartZoom")
    private let show: @MainActor (IOSurfaceRef) -> Void

    init(show: @escaping @MainActor (IOSurfaceRef) -> Void) {
        self.show = show
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, Self.isComplete(sampleBuffer), let pixels = sampleBuffer.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(pixels)?.takeUnretainedValue() else { return }
        let show = show
        DispatchQueue.main.async { MainActor.assumeIsolated { show(surface) } }
    }

    /// Frames that only say nothing changed carry no picture.
    private static func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int else { return false }
        return SCFrameStatus(rawValue: raw) == .complete
    }
}
