import Foundation

enum SystemPointerError: LocalizedError, Equatable {
    /// macOS refused the write to `com.apple.universalaccess`; the app needs Full Disk Access.
    case permissionDenied
    /// The private UniversalAccess function for live pointer size is missing on this macOS.
    case sizeAPIUnavailable
    /// Another private UniversalAccess function is missing on this macOS.
    case featureUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "macOS blocked the change. Give Pointer Colors Full Disk Access, then reopen the app."
        case .sizeAPIUnavailable:
            return "This version of macOS doesn't offer live pointer size changes."
        case .featureUnavailable:
            return "This version of macOS doesn't offer that setting."
        }
    }
}

/// Reads and changes the system pointer: the same settings as
/// System Settings › Accessibility › Display › Pointer.
///
/// Colors and size live in the `com.apple.universalaccess` preferences domain
/// (`cursorOutline`, `cursorFill`, `mouseDriverCursorSize`).
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

    /// True when this process may change pointer settings (Full Disk Access is granted).
    func canWriteSettings() -> Bool {
        let current = copy(Self.outlineKey)
        set(Self.outlineKey, current)
        return synchronize()
    }

    // MARK: Size

    func currentScale() -> Double {
        if let scale = universalAccess.cursorScale() { return scale }
        return (copy(Self.scaleKey) as? NSNumber)?.doubleValue ?? Self.minimumScale
    }

    /// Changes the size live and saves it. `UACursorSetScale` alone only updates this process:
    /// without Full Disk Access the save never reaches the system and the size snaps back.
    func setScale(_ scale: Double) throws {
        let value = scale.clamped(to: Self.minimumScale...Self.maximumScale)
        let previous = currentScale()
        guard universalAccess.setCursorScale(value) else { throw SystemPointerError.sizeAPIUnavailable }
        set(Self.scaleKey, value as CFNumber)
        guard synchronize() else {
            // Undo the in-process change so the app doesn't report a size the system never took.
            _ = universalAccess.setCursorScale(previous)
            set(Self.scaleKey, previous as CFNumber)
            throw SystemPointerError.permissionDenied
        }
    }

    // MARK: Shake to find

    var shakeToFindEnabled: Bool? { universalAccess.shakeToFindEnabled() }

    func setShakeToFind(_ enabled: Bool) throws {
        guard universalAccess.setShakeToFind(enabled) else { throw SystemPointerError.featureUnavailable }
        guard synchronize() else { throw SystemPointerError.permissionDenied }
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
