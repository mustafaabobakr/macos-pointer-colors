import CoreGraphics
import Foundation

/// Picks taps out of a touch surface's frames: one finger that touches and lifts again quickly,
/// with the mouse held still. A rest, a drag, a second finger or a finger brushing the mouse while
/// it's moved isn't a tap.
struct TouchTaps {
    /// The longest touch that still counts as a tap. A Magic Mouse tap lasts about 0.1 s.
    static let longestTap: TimeInterval = 0.25
    /// The farthest the pointer may travel, in points, during a touch that still counts as a tap.
    /// A real tap moves it 0–5 points; a finger brushing the mouse as it's moved, 40 or more.
    static let farthestTapTravel: CGFloat = 10
    private var touchStart: TimeInterval?
    private var hadMoreFingers = false
    private var lastPointer: CGPoint?
    private var travel: CGFloat = 0

    /// When this frame lifts the finger of a tap, the time it touched down; otherwise nil.
    /// `pointer` is where the pointer is at this frame.
    mutating func frame(fingers: Int, at time: TimeInterval, pointer: CGPoint = .zero) -> TimeInterval? {
        guard fingers == 0 else {
            touching(fingers: fingers, at: time, pointer: pointer)
            return nil
        }
        defer { touchStart = nil; hadMoreFingers = false; lastPointer = nil; travel = 0 }
        guard let touchStart, !hadMoreFingers, time - touchStart <= Self.longestTap else { return nil }
        guard travel + distance(to: pointer) <= Self.farthestTapTravel else { return nil }
        return touchStart
    }

    private mutating func touching(fingers: Int, at time: TimeInterval, pointer: CGPoint) {
        if touchStart == nil { touchStart = time }
        if fingers > 1 { hadMoreFingers = true }
        travel += distance(to: pointer)
        lastPointer = pointer
    }

    private func distance(to pointer: CGPoint) -> CGFloat {
        guard let lastPointer else { return 0 }
        return hypot(pointer.x - lastPointer.x, pointer.y - lastPointer.y)
    }
}
