import CoreGraphics

/// The modifier keys that, held down, pause hover focus so the pointer can cross windows without
/// changing focus. Saved as its raw value.
struct HoverPauseKeys: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let control = HoverPauseKeys(rawValue: 1 << 0)
    static let option = HoverPauseKeys(rawValue: 1 << 1)
    static let shift = HoverPauseKeys(rawValue: 1 << 2)
    static let command = HoverPauseKeys(rawValue: 1 << 3)

    /// Every key, which is how hover focus has always behaved.
    static let all: HoverPauseKeys = [.control, .option, .shift, .command]

    /// The event flag each key sets, in the order macOS menus show modifiers.
    private static let flagsByKey: [(key: HoverPauseKeys, flag: CGEventFlags)] =
        [(.control, .maskControl), (.option, .maskAlternate), (.shift, .maskShift), (.command, .maskCommand)]

    /// A saved value, keeping only the keys this version knows.
    init(saved rawValue: Int) {
        self = HoverPauseKeys(rawValue: rawValue).intersection(.all)
    }

    init(rawValue: Int) { self.rawValue = rawValue }

    /// The event flags that pause focusing.
    var flags: CGEventFlags {
        Self.flagsByKey.reduce(into: CGEventFlags()) { flags, entry in
            if contains(entry.key) { flags.insert(entry.flag) }
        }
    }

    /// Adds `key` when `on`, removes it otherwise.
    mutating func set(_ key: HoverPauseKeys, _ on: Bool) {
        if on { insert(key) } else { remove(key) }
    }
}
