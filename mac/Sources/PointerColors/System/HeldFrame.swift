// IOSurface references and use counts are safe from any thread; the module just isn't annotated.
@preconcurrency import IOSurface

/// A frame of a screen capture kept for drawing. ScreenCaptureKit paints new frames into the
/// surfaces it handed out before unless they're marked in use, so while one is held it is: a sharp
/// zoom drawing from it later never reads a frame half painted over.
final class HeldFrame: Sendable {
    let surface: IOSurfaceRef

    init(_ surface: IOSurfaceRef) {
        self.surface = surface
        IOSurfaceIncrementUseCount(surface)
    }

    deinit {
        IOSurfaceDecrementUseCount(surface)
    }
}
