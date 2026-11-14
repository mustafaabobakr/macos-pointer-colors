import CoreGraphics
import Foundation

/// Picks taps out of a touch surface's frames: one finger that touches and lifts again quickly,
/// with the mouse held still. A rest, a drag, a second finger or a finger brushing the mouse while
/// it's moved isn't a tap, and neither is a touch that comes right after a flicker of contact.
struct TouchTaps {
    var limits = TapLimits()
    private var touchStart: TimeInterval?
    private var lastFlicker = -TimeInterval.infinity
    private var hadMoreFingers = false
    private var lastPointer: CGPoint?
    private var travel: CGFloat = 0
    private var biggestContact: Float = 0

    /// When this frame lifts the finger of a tap, the time it touched down; otherwise nil.
    /// `pointer` is where the pointer is at this frame, and `size` the biggest contact in it.
    mutating func frame(fingers: Int, at time: TimeInterval, pointer: CGPoint = .zero, size: Float = 1) -> TimeInterval? {
        guard fingers == 0 else {
            touching(fingers: fingers, at: time, pointer: pointer)
            biggestContact = max(biggestContact, size)
            return nil
        }
        defer { touchStart = nil; hadMoreFingers = false; lastPointer = nil; travel = 0; biggestContact = 0 }
        guard let touchStart else { return nil }
        guard time - touchStart >= limits.shortest else { lastFlicker = time; return nil }
        guard touchStart - lastFlicker >= limits.settleAfterFlicker else { return nil }
        guard !hadMoreFingers, limits.lasts(time - touchStart) else { return nil }
        guard travel + distance(to: pointer) <= limits.farthestTravel else { return nil }
        guard biggestContact >= limits.lightest else { return nil }
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
    /// The longest touch that still counts as a tap. A Magic Mouse tap lasts about 0.1 s; in the log,
    /// both confirmed stray zooms were touches of 0.18–0.21 s as a hand settled on the mouse.
    var longest: TimeInterval = Self.defaultLongest
    /// The farthest the pointer may travel, in points, during a touch that still counts as a tap.
    /// A real tap moves it 0–5 points; a finger brushing the mouse as it's moved, 40 or more.
    var farthestTravel: CGFloat = Self.defaultFarthestTravel
    /// How long after a flicker of contact a touch is still the finger settling, not a tap. In the
    /// log a grip change flickered, then two still touches 0.06 s later zoomed by themselves; every
    /// real double tap came 0.46 s or more after a flicker.
    var settleAfterFlicker: TimeInterval = Self.defaultSettleAfterFlicker
    /// The smallest contact, as MultitouchSupport sizes it, that counts as a tap. Real fingertip taps
    /// in the log were 0.62–1.12; a finger grazing the mouse's side that zoomed by itself, 0.12–0.25.
    var lightest: Float = Self.defaultLightest

    static let defaultShortest: TimeInterval = 0.05
    static let defaultLongest: TimeInterval = 0.17
    static let defaultLightest: Float = 0.5
    static let defaultFarthestTravel: CGFloat = 10
    static let defaultSettleAfterFlicker: TimeInterval = 0.3

    func lasts(_ length: TimeInterval) -> Bool { length >= shortest && length <= longest }
}
