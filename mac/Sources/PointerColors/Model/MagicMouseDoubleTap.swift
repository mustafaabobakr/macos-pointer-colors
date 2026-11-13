import CoreGraphics
import Foundation

/// Tells a double tap on a Magic Mouse from single taps, rests, clicks and scrolls. A quick touch
/// that pressed a button is a click, and one that scrolled is a flick, so neither counts.
struct MagicMouseDoubleTap {
    private var taps = TouchTaps()
    private var presses: DoublePress
    /// When a button last went down or the mouse last scrolled.
    private var lastInterruption = -TimeInterval.infinity

    /// Seconds the second tap may come after the first.
    var window: TimeInterval {
        get { presses.window }
        set { presses.window = newValue }
    }

    /// What a touch may do and still count as a tap.
    var limits: TapLimits {
        get { taps.limits }
        set { taps.limits = newValue }
    }

    init(window: TimeInterval) { presses = DoublePress(window: window) }

    /// A mouse button went down, or the mouse scrolled, at `time`; it also ends any tap waiting
    /// for its second.
    mutating func interrupt(at time: TimeInterval) {
        lastInterruption = time
        presses = DoublePress(window: presses.window)
    }

    /// True when this frame finishes a double tap. `pointer` is where the pointer is at this frame.
    mutating func frame(fingers: Int, at time: TimeInterval, pointer: CGPoint = .zero) -> Bool {
        guard let touchStart = taps.frame(fingers: fingers, at: time, pointer: pointer) else { return false }
        guard lastInterruption < touchStart - 0.05 else { return false }
        return presses.press(at: time)
    }
}
