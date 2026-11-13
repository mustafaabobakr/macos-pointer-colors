import Foundation

/// Tells a double press of one button from two separate presses.
struct DoublePress {
    /// Seconds the second press may come after the first.
    var window: TimeInterval
    private var lastPress: TimeInterval?

    init(window: TimeInterval) { self.window = window }

    /// True when this press comes within `window` of the last one. A double press starts afresh,
    /// so a third quick press counts as a first again.
    mutating func press(at time: TimeInterval) -> Bool {
        if let lastPress, time - lastPress <= window {
            self.lastPress = nil
            return true
        }
        lastPress = time
        return false
    }
}
