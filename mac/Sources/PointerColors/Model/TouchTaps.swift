import Foundation

/// Picks taps out of a touch surface's frames: one finger that touches and lifts again quickly.
/// A rest, a drag or a second finger isn't a tap.
struct TouchTaps {
    /// The longest touch that still counts as a tap. A Magic Mouse tap lasts about 0.1 s.
    static let longestTap: TimeInterval = 0.25
    private var touchStart: TimeInterval?
    private var hadMoreFingers = false

    /// When this frame lifts the finger of a tap, the time it touched down; otherwise nil.
    mutating func frame(fingers: Int, at time: TimeInterval) -> TimeInterval? {
        guard fingers == 0 else {
            if touchStart == nil { touchStart = time }
            if fingers > 1 { hadMoreFingers = true }
            return nil
        }
        defer { touchStart = nil; hadMoreFingers = false }
        guard let touchStart, !hadMoreFingers, time - touchStart <= Self.longestTap else { return nil }
        return touchStart
    }
}
