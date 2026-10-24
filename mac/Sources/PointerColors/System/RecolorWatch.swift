import AppKit

/// Waits for macOS to draw the pointer in new colors, then runs a step straight away.
///
/// macOS changes the pointer size instantly but takes anywhere from a few milliseconds to over half
/// a second to redraw new colors, so a display's size has to wait for them. The wait polls every
/// millisecond on its own thread: polling from the main thread lands a frame or two late, and that
/// frame shows the new colors at the old size.
final class RecolorWatch {
    private let lock = NSLock()
    private var cancelled = false

    /// Create it before writing the new colors: it compares against the pointer as drawn now.
    /// `onRecolor` runs on the watching thread, then `then` on the main thread, unless cancelled.
    /// Both run anyway after `timeout`, so a recolor that never shows up can't hold the size back.
    init(timeout: TimeInterval = 1, onRecolor: @escaping () -> Void, then: @escaping @MainActor () -> Void) {
        let oldImage = Self.cursorImage()
        let deadline = Date().addingTimeInterval(timeout)
        Thread.detachNewThread { [self] in
            while Date() < deadline, !isCancelled, Self.cursorImage() == oldImage {
                usleep(1000)
            }
            guard !isCancelled else { return }
            onRecolor()
            DispatchQueue.main.async { [self] in
                guard !isCancelled else { return }
                MainActor.assumeIsolated { then() }
            }
        }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }

    private var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    /// The pointer as macOS currently draws it.
    private static func cursorImage() -> Data? {
        NSCursor.currentSystem?.image.cgImage(forProposedRect: nil, context: nil, hints: nil)?
            .dataProvider?.data as Data?
    }
}
