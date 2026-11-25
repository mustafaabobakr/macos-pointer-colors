import CoreGraphics

/// Where the pointer will be a moment from now, from how fast it has been moving.
///
/// A window that follows the pointer reaches the screen about a frame after the pointer does
/// (measured: about 9 ms behind, moved from the event tap). With the speed smoothed, a 7 ms lead
/// measured closest to none behind on average. When the moves stop, the caller calls `reset()` and
/// places it at the pointer itself, so it never stays ahead.
struct PointerLead {
    /// How far ahead to place it, in seconds.
    static let lead = 0.007
    /// Moves further apart than this are a new movement, not the same one.
    private static let maxGap = 0.05
    /// Moves closer together than this give a speed too noisy to trust.
    private static let minGap = 0.001
    /// How much each new move counts toward the speed, 0 to 1.
    private static let smoothing = 0.25

    private var last: (point: CGPoint, time: Double)?
    private var velocity = CGVector.zero

    /// Where the pointer, at `point` at `time` seconds, will be `lead` seconds later.
    mutating func predict(_ point: CGPoint, at time: Double) -> CGPoint {
        guard let last, time - last.time < Self.maxGap else {
            reset()
            self.last = (point, time)
            return point
        }
        let gap = time - last.time
        if gap >= Self.minGap {
            let current = CGVector(dx: (point.x - last.point.x) / gap, dy: (point.y - last.point.y) / gap)
            velocity = CGVector(dx: velocity.dx + (current.dx - velocity.dx) * Self.smoothing,
                                dy: velocity.dy + (current.dy - velocity.dy) * Self.smoothing)
            self.last = (point, time)
        }
        return CGPoint(x: point.x + velocity.dx * Self.lead, y: point.y + velocity.dy * Self.lead)
    }

    mutating func reset() {
        last = nil
        velocity = .zero
    }
}
