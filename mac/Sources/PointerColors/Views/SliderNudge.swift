import Foundation

/// How far one press on a slider's end icon moves its value.
enum SliderNudge {
    /// One unit of the last digit a `%.Nf` label shows, in the value's own units: `%.2f s` gives
    /// 0.01, and `%.0f%%` over a 0–1 value shown ×100 gives 0.01. Nil for any other format.
    static func smallestShown(format: String, scale: Double) -> Double? {
        guard let match = format.firstMatch(of: #/%\.(\d+)f/#), let digits = Int(match.1), scale > 0 else { return nil }
        return pow(10, -Double(digits)) / scale
    }

    /// The press step for a slider: its own step, else the smallest change its label shows, else
    /// a hundredth of its range.
    static func amount(step: Double?, format: String, scale: Double, range: ClosedRange<Double>) -> Double {
        step ?? smallestShown(format: format, scale: scale) ?? (range.upperBound - range.lowerBound) / 100
    }

    /// `value` moved by `delta`, kept on the grid of `delta`'s size from the range's low end (so
    /// repeated presses don't drift) and inside the range.
    static func nudged(_ value: Double, by delta: Double, in range: ClosedRange<Double>) -> Double {
        let grid = abs(delta)
        let moved = value + delta
        let snapped = grid > 0 ? range.lowerBound + ((moved - range.lowerBound) / grid).rounded() * grid : moved
        return min(max(snapped, range.lowerBound), range.upperBound)
    }
}
