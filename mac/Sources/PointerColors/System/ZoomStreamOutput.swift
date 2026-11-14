import CoreMedia
import CoreVideo
import ScreenCaptureKit

/// Hands each complete frame of a screen capture to the main actor, held from the moment it arrives
/// so the capture can't paint the next frame into it on the way, with the capture it came from: a
/// capture that's stopping can still send frames, which a newer zoom must not show.
final class ZoomStreamOutput: NSObject, SCStreamOutput {
    let queue = DispatchQueue(label: "PointerColors.smartZoom")
    private let show: @MainActor (HeldFrame, ObjectIdentifier) -> Void

    init(show: @escaping @MainActor (HeldFrame, ObjectIdentifier) -> Void) {
        self.show = show
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, Self.isComplete(sampleBuffer), let pixels = sampleBuffer.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(pixels)?.takeUnretainedValue() else { return }
        let show = show, frame = HeldFrame(surface), source = ObjectIdentifier(stream)
        DispatchQueue.main.async { MainActor.assumeIsolated { show(frame, source) } }
    }

    /// Frames that only say nothing changed carry no picture.
    private static func isComplete(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int else { return false }
        return SCFrameStatus(rawValue: raw) == .complete
    }
}
