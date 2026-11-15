import CoreGraphics
import Foundation

/// Eases the lens's offset from the pointer, so it glides to a new spot when its placement picks
/// another side, while still following the pointer at once as it moves.
struct LensGlide {
    /// Seconds to cover half the remaining way.
    static let halfLife = 0.04

    private(set) var offset: CGVector?

    /// Starts afresh, so the next step lands on its target at once.
    mutating func reset() { offset = nil }

    /// The offset `seconds` after the last step, eased toward `target`; `snaps` lands on it at once.
    mutating func step(toward target: CGVector, after seconds: Double, snaps: Bool) -> CGVector {
        guard let current = offset, !snaps else {
            offset = target
            return target
        }
        let kept = pow(0.5, max(seconds, 0) / Self.halfLife)
        var next = CGVector(dx: target.dx + (current.dx - target.dx) * kept, dy: target.dy + (current.dy - target.dy) * kept)
        if abs(next.dx - target.dx) < 0.25, abs(next.dy - target.dy) < 0.25 { next = target }
        offset = next
        return next
    }
}
