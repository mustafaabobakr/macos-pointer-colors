import AppKit
import Carbon.HIToolbox

/// A key plus modifiers, stored in Carbon terms so it can be registered as a global hotkey.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    /// What the key itself showed when recorded, e.g. "P" or "→".
    var keyLabel: String

    /// Builds a combo from a recorded key press. Needs ⌘, ⌥ or ⌃, so plain typing never triggers it.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
        keyCode = UInt32(event.keyCode)
        carbonModifiers = Self.carbon(flags)
        keyLabel = Self.label(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
    }

    var displayString: String {
        let symbols: [(UInt32, String)] = [(UInt32(controlKey), "⌃"), (UInt32(optionKey), "⌥"),
                                          (UInt32(shiftKey), "⇧"), (UInt32(cmdKey), "⌘")]
        let prefix = symbols.filter { carbonModifiers & $0.0 != 0 }.map(\.1).joined()
        return prefix + keyLabel
    }

    private static func carbon(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private static let specialKeys: [Int: String] = [
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_Escape: "⎋",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(keyCode: UInt16, characters: String?) -> String {
        if let special = specialKeys[Int(keyCode)] { return special }
        return (characters ?? "?").uppercased()
    }
}

/// Things a global shortcut can do.
enum ShortcutAction: String, CaseIterable, Identifiable, Codable {
    case nextPair, previousPair, biggerPointer, smallerPointer, resetPointer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nextPair: return String(localized: "Apply the next pair")
        case .previousPair: return String(localized: "Apply the previous pair")
        case .biggerPointer: return String(localized: "Make the pointer bigger")
        case .smallerPointer: return String(localized: "Make the pointer smaller")
        case .resetPointer: return String(localized: "Reset to the macOS default, normal size")
        }
    }
}
