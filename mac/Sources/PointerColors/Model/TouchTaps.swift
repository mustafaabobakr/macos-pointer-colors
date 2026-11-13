import CoreGraphics
import Foundation

/// Picks taps out of a touch surface's frames: one finger that touches and lifts again quickly,
/// with the mouse held still. A rest, a drag, a second finger or a finger brushing the mouse while
/// it's moved isn't a tap.
struct TouchTaps {
    var limits = TapLimits()
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
        guard let touchStart, !hadMoreFingers, limits.lasts(time - touchStart) else { return nil }
        guard travel + distance(to: pointer) <= limits.farthestTravel else { return nil }
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

/// What a touch may do and still count as a tap. The defaults come from the zoom diagnostics log.
struct TapLimits: Equatable {
    /// The shortest touch that counts as a tap. A real tap lasts 0.06 s or more; a finger shifting
    /// on the mouse can flicker a touch for 0.02–0.03 s.
    var shortest: TimeInterval = Self.defaultShortest
    /// The longest touch that still counts as a tap. A Magic Mouse tap lasts about 0.1 s.
    var longest: TimeInterval = Self.defaultLongest
    /// The farthest the pointer may travel, in points, during a touch that still counts as a tap.
    /// A real tap moves it 0–5 points; a finger brushing the mouse as it's moved, 40 or more.
    var farthestTravel: CGFloat = Self.defaultFarthestTravel

    static let defaultShortest: TimeInterval = 0.05
    static let defaultLongest: TimeInterval = 0.25
    static let defaultFarthestTravel: CGFloat = 10

    func lasts(_ length: TimeInterval) -> Bool { length >= shortest && length <= longest }
}
