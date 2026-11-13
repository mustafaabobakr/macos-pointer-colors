import AppKit

// DIAG: temporary. Logs every Magic Mouse touch and zoom toggle to find zooms nobody asked for.
@MainActor
final class ZoomDiagnostics {
    static let shared = ZoomDiagnostics()
    let file = BatteryHistoryStore.defaultFolder.appending(path: "zoom-diagnostics.log")
    private var touchStart: TimeInterval?
    private var startMouse = CGPoint.zero
    private var maxFingers = 0
    private var travel = 0.0
    private var lastMouse = CGPoint.zero
    private var frames = 0

    func frame(fingers: Int, at time: TimeInterval) {
        let mouse = NSEvent.mouseLocation
        guard fingers == 0 else {
            if touchStart == nil { (touchStart, startMouse, maxFingers, travel, frames) = (time, mouse, 0, 0, 0); lastMouse = mouse }
            maxFingers = max(maxFingers, fingers)
            travel += hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y)
            lastMouse = mouse
            frames += 1
            return
        }
        guard let start = touchStart else { return }
        touchStart = nil
        let moved = hypot(mouse.x - startMouse.x, mouse.y - startMouse.y)
        write(String(format: "touch %.3f dur=%.3f fingers=%d frames=%d pointerTravel=%.1f net=%.1f",
                     start, time - start, maxFingers, frames, travel, moved))
    }

    func note(_ text: String, at time: TimeInterval = CACurrentMediaTime()) {
        write(String(format: "%@ %.3f", text, time))
    }

    private func write(_ line: String) {
        let stamp = Date.now.formatted(.iso8601.time(includingFractionalSeconds: true))
        guard let data = "\(stamp) \(line)\n".data(using: .utf8) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: file)
        }
    }
}
