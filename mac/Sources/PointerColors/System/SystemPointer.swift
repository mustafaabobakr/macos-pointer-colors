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
    /// While rendering feature screenshots the app shows demo settings and must never change the
    /// real pointer, so every write is skipped. What it would have set is kept in `rendered`
    /// instead, so a clip shows the pair that was just picked.
    private let isReadOnly = ScreenshotRenderer.isRendering
    nonisolated(unsafe) private static var rendered: (outline: RGBA, fill: RGBA, scale: Double?)?
    /// The size under a press: while a press has the pointer shrunk, it's the size reported and saved.
    nonisolated(unsafe) private static var pressedFrom: Double?

    // MARK: Colors

    func currentColors() -> (outline: RGBA, fill: RGBA) {
        if isReadOnly, let rendered = Self.rendered { return (rendered.outline, rendered.fill) }
        let outline = RGBA(preferenceValue: copy(Self.outlineKey)) ?? PointerPair.macOSLight.outline
        let fill = RGBA(preferenceValue: copy(Self.fillKey)) ?? PointerPair.macOSLight.fill
        return (outline, fill)
    }

    /// Writes both colors directly, or through `defaults` when macOS refuses the direct write.
    func apply(_ pair: PointerPair) throws {
        guard !isReadOnly else { Self.rendered = (pair.outline, pair.fill, Self.rendered?.scale); return }
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
        guard !isReadOnly else { return true }
        let current = copy(Self.scaleKey)
        set(Self.scaleKey, current)
        if synchronize() { return true }
        return DefaultsTool.write(Self.scaleKey as String, number: currentScale())
    }

    // MARK: Size

    func currentScale() -> Double {
        if let pressedFrom = Self.pressedFrom { return pressedFrom }
        if isReadOnly, let scale = Self.rendered?.scale { return scale }
        if let scale = universalAccess.cursorScale() { return scale }
        return (copy(Self.scaleKey) as? NSNumber)?.doubleValue ?? Self.minimumScale
    }

    /// Changes the size live and saves it. `UACursorSetScale` alone only updates this process, so
    /// the size is also saved directly or, when that's refused, through `defaults`.
    func setScale(_ scale: Double) throws {
        let value = scale.clamped(to: Self.minimumScale...Self.maximumScale)
        guard !isReadOnly else { return renderScale(value) }
        let previous = currentScale()
        guard universalAccess.setCursorScale(value) else { throw SystemPointerError.sizeAPIUnavailable }
        if Self.pressedFrom != nil { Self.pressedFrom = value }
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

    /// The size a render would have set, kept with the colors it shows.
    private func renderScale(_ value: Double) {
        let colors = currentColors()
        Self.rendered = (colors.outline, colors.fill, value)
    }

    // MARK: Press

    /// Shows `scale` live for a press, without saving it. Until `endPress`, `currentScale` keeps
    /// reporting the size from before the press.
    func showPressed(_ scale: Double) {
        guard !isReadOnly else { return }
        if Self.pressedFrom == nil { Self.pressedFrom = currentScale() }
        _ = universalAccess.setCursorScale(scale)
    }

    /// Puts the size from before the press back on screen.
    func endPress() {
        guard let pressedFrom = Self.pressedFrom else { return }
        Self.pressedFrom = nil
        _ = universalAccess.setCursorScale(pressedFrom)
    }

    // MARK: Shake to find

    var shakeToFindEnabled: Bool? { universalAccess.shakeToFindEnabled() }

    func setShakeToFind(_ enabled: Bool) throws {
        guard !isReadOnly else { return }
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
