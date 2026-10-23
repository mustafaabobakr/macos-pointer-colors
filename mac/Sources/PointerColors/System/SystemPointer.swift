import Foundation

enum SystemPointerError: LocalizedError, Equatable {
    /// macOS refused the write to `com.apple.universalaccess`; the app needs Full Disk Access.
    case permissionDenied
    /// The private UniversalAccess function for live pointer size is missing on this macOS.
    case sizeAPIUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "macOS blocked the change. Give Pointer Colors Full Disk Access, then try again."
        case .sizeAPIUnavailable:
            return "This version of macOS doesn't offer live pointer size changes."
        }
    }
}

/// Reads and changes the system pointer: the same settings as
/// System Settings › Accessibility › Display › Pointer.
///
/// Colors live in the `com.apple.universalaccess` preferences domain (`cursorOutline`, `cursorFill`).
/// That domain is privacy-protected: third-party apps can only write it with Full Disk Access.
/// After writing, the Universal Access "mouse settings changed" notification is posted so the
/// system can pick the new colors up.
///
/// Size goes through `UACursorSetScale` in Apple's private UniversalAccessCore framework, the call
/// System Settings itself makes. It is private API, so it is looked up at runtime and may disappear.
struct SystemPointer {
    static let minimumScale = 1.0
    static let maximumScale = 4.0

    private static let domain = "com.apple.universalaccess" as CFString
    private static let outlineKey = "cursorOutline" as CFString
    private static let fillKey = "cursorFill" as CFString
    private static let scaleKey = "mouseDriverCursorSize" as CFString

    private let universalAccess = UniversalAccessCore.shared

    // MARK: Colors

    func currentColors() -> (outline: RGBA, fill: RGBA) {
        let outline = RGBA(preferenceValue: copy(Self.outlineKey)) ?? PointerPair.classic.outline
        let fill = RGBA(preferenceValue: copy(Self.fillKey)) ?? PointerPair.classic.fill
        return (outline, fill)
    }

    func apply(_ pair: PointerPair) throws {
        set(Self.outlineKey, pair.outline.preferenceValue as CFDictionary)
        set(Self.fillKey, pair.fill.preferenceValue as CFDictionary)
        guard synchronize() else { throw SystemPointerError.permissionDenied }
        universalAccess.postMouseSettingsChanged()
    }

    /// Clears both color keys so macOS falls back to black and white.
    func resetColors() throws {
        set(Self.outlineKey, nil)
        set(Self.fillKey, nil)
        guard synchronize() else { throw SystemPointerError.permissionDenied }
        universalAccess.postMouseSettingsChanged()
    }

    /// True when this process may write pointer colors (Full Disk Access is granted).
    func canWriteColors() -> Bool {
        let current = copy(Self.outlineKey)
        set(Self.outlineKey, current)
        return synchronize()
    }

    // MARK: Size

    func currentScale() -> Double {
        if let scale = universalAccess.cursorScale() { return scale }
        return (copy(Self.scaleKey) as? NSNumber)?.doubleValue ?? Self.minimumScale
    }

    func setScale(_ scale: Double) throws {
        let value = scale.clamped(to: Self.minimumScale...Self.maximumScale)
        guard universalAccess.setCursorScale(value) else { throw SystemPointerError.sizeAPIUnavailable }
    }

    // MARK: Preferences

    private func copy(_ key: CFString) -> CFPropertyList? {
        CFPreferencesCopyValue(key, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private func set(_ key: CFString, _ value: CFPropertyList?) {
        CFPreferencesSetValue(key, value, Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private func synchronize() -> Bool {
        CFPreferencesSynchronize(Self.domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
}
