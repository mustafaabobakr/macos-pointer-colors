import AppKit

/// Modifier keys held down during a drag, e.g. ⌥ Option to draw with the laser.
struct HoldKeys: OptionSet, Hashable {
    let rawValue: Int

    static let control = HoldKeys(rawValue: 1 << 0)
    static let option = HoldKeys(rawValue: 1 << 1)
    static let shift = HoldKeys(rawValue: 1 << 2)
    static let command = HoldKeys(rawValue: 1 << 3)

    /// In the order macOS writes them.
    private static let keys: [(key: HoldKeys, flag: NSEvent.ModifierFlags, symbol: String, name: String)] = [
        (.control, .control, "⌃", String(localized: "Control")),
        (.option, .option, "⌥", String(localized: "Option")),
        (.shift, .shift, "⇧", String(localized: "Shift")),
        (.command, .command, "⌘", String(localized: "Command")),
    ]

    init(rawValue: Int) { self.rawValue = rawValue }

    init(flags: NSEvent.ModifierFlags) {
        self = Self.keys.filter { flags.contains($0.flag) }.reduce(into: []) { $0.insert($1.key) }
    }

    /// Every one of these keys is down in `flags`; other keys held too don't matter.
    func areHeld(in flags: NSEvent.ModifierFlags) -> Bool {
        HoldKeys(flags: flags).isSuperset(of: self)
    }

    /// "⌃⌥", or the symbol and name for a single key, "⌥ Option".
    var title: String {
        let held = Self.keys.filter { contains($0.key) }
        if held.count == 1 { return "\(held[0].symbol) \(held[0].name)" }
        return held.map(\.symbol).joined()
    }

    /// Just the symbols, "⌥" or "⌃⌥".
    var symbols: String {
        Self.keys.filter { contains($0.key) }.map(\.symbol).joined()
    }
}
