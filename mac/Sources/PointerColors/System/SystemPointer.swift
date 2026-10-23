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
            return String(localized: "macOS blocked the change. Give Pointer Colors Full Disk Access, then reopen the app.")
        case .sizeAPIUnavailable:
            return String(localized: "This version of macOS doesn't offer live pointer size changes.")
        case .featureUnavailable:
            return String(localized: "This version of macOS doesn't offer that setting.")
        }
    }
}

/// Reads and changes the system pointer: the same settings as
/// System Settings › Accessibility › Display › Pointer.
///
/// Colors and size live in the `com.apple.universalaccess` preferences domain
/// (`cursorOutline`, `cursorFill`, `mouseDriverCursorSize`).
/// That domain is privacy-protected: a direct write needs Full Disk Access, so when it is refused
/// the app falls back to Apple's `defaults` tool (see DefaultsTool).
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
        let outline = RGBA(preferenceValue: copy(Self.outlineKey)) ?? PointerPair.macOSLight.outline
        let fill = RGBA(preferenceValue: copy(Self.fillKey)) ?? PointerPair.macOSLight.fill
        return (outline, fill)
    }

    /// Writes both colors directly, or through `defaults` when macOS refuses the direct write.
    func apply(_ pair: PointerPair) throws {
        set(Self.outlineKey, pair.outline.preferenceValue as CFDictionary)
        set(Self.fillKey, pair.fill.preferenceValue as CFDictionary)
        if !synchronize() {
            let written = DefaultsTool.write(Self.outlineKey as String, color: pair.outline)
                && DefaultsTool.write(Self.fillKey as String, color: pair.fill)
            guard written else { throw SystemPointerError.permissionDenied }
        }
        universalAccess.postMouseSettingsChanged()
    }

    /// True when pointer settings can be changed, directly or through `defaults`.
    func canWriteSettings() -> Bool {
        let current = copy(Self.scaleKey)
        set(Self.scaleKey, current)
        if synchronize() { return true }
        return DefaultsTool.write(Self.scaleKey as String, number: currentScale())
    }

    // MARK: Size

    func currentScale() -> Double {
        if let scale = universalAccess.cursorScale() { return scale }
        return (copy(Self.scaleKey) as? NSNumber)?.doubleValue ?? Self.minimumScale
    }

    /// Changes the size live and saves it. `UACursorSetScale` alone only updates this process, so
    /// the size is also saved directly or, when that's refused, through `defaults`.
    func setScale(_ scale: Double) throws {
        let value = scale.clamped(to: Self.minimumScale...Self.maximumScale)
        let previous = currentScale()
        guard universalAccess.setCursorScale(value) else { throw SystemPointerError.sizeAPIUnavailable }
        set(Self.scaleKey, value as CFNumber)
        if synchronize() || DefaultsTool.write(Self.scaleKey as String, number: value) {
            universalAccess.postMouseSettingsChanged()
            return
        }
        // Undo the in-process change so the app doesn't report a size the system never took.
        _ = universalAccess.setCursorScale(previous)
        set(Self.scaleKey, previous as CFNumber)
        throw SystemPointerError.permissionDenied
    }

    // MARK: Shake to find

    var shakeToFindEnabled: Bool? { universalAccess.shakeToFindEnabled() }

    func setShakeToFind(_ enabled: Bool) throws {
        guard universalAccess.setShakeToFind(enabled) else { throw SystemPointerError.featureUnavailable }
        if synchronize() { return }
        // The same switch as a global default: true turns shake-to-find off.
        let written = DefaultsTool.write("CGDisableCursorLocationMagnification", bool: !enabled, domain: "-g")
        guard written else { throw SystemPointerError.permissionDenied }
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
