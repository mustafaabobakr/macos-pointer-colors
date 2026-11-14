import Foundation

/// Turns double taps from macOS and from Pointer Colors' own detection into zooms, as
/// `detection` says. With both, a zoom needs the two to land within `agreement` of each other;
/// macOS's comes on the second tap's lift, a few milliseconds from Pointer Colors' own.
struct TapVotes {
    var detection: TapDetection
    static let agreement: TimeInterval = 0.2

    private var lastMacOS = -TimeInterval.infinity
    private var lastOwn = -TimeInterval.infinity

    /// macOS recognized a double tap at `time`; true when that zooms.
    mutating func macOS(at time: TimeInterval) -> Bool {
        guard detection.usesMacOS else { return false }
        guard detection == .both else { return true }
        lastMacOS = time
        return agreed(time - lastOwn)
    }

    /// Pointer Colors' own detection found a double tap at `time`; true when that zooms.
    mutating func own(at time: TimeInterval) -> Bool {
        guard detection.usesOwnTaps else { return false }
        guard detection == .both else { return true }
        lastOwn = time
        return agreed(time - lastMacOS)
    }

    /// One agreement makes one zoom: both votes are used up.
    private mutating func agreed(_ gap: TimeInterval) -> Bool {
        guard abs(gap) <= Self.agreement else { return false }
        lastMacOS = -.infinity
        lastOwn = -.infinity
        return true
    }
}
