import Foundation

/// How much the Bigger and Smaller pointer shortcuts change the size each time.
enum SizeStep {
    static let range = 0.1...1.0
    static let standard = 0.25

    /// A stored step, or the standard one when there is none, held inside `range`.
    static func resolved(_ stored: Double?) -> Double {
        (stored ?? standard).clamped(to: range)
    }

    /// The size after one press: one step up or down, kept within the pointer's limits.
    static func next(from scale: Double, step: Double, bigger: Bool, limits: ClosedRange<Double>) -> Double {
        (scale + (bigger ? step : -step)).clamped(to: limits)
    }
}

/// The sound played when a pair is applied: one of the sounds macOS ships in /System/Library/Sounds.
enum ApplySound {
    static let standard = "Pop"
    /// Every sound in /System/Library/Sounds, by file name.
    static let names = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop",
                        "Purr", "Sosumi", "Submarine", "Tink"]

    /// A stored sound, or Pop when there is none or it isn't one of `names`.
    static func resolved(_ stored: String?) -> String {
        guard let stored, names.contains(stored) else { return standard }
        return stored
    }
}
