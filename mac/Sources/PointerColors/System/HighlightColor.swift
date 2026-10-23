import AppKit

/// The system text-selection highlight (System Settings › Appearance › Highlight color), stored as
/// `AppleHighlightColor` = "r g b Name" in the global domain. That domain isn't protected, so no
/// permission is needed. Apps pick the new color up when they next redraw or relaunch.
enum HighlightColor {
    private static let key = "AppleHighlightColor"
    private static let savedKey = "originalHighlightColor"

    /// A light tint of the pair's more colorful color, like the tints macOS uses itself.
    static func tint(for pair: PointerPair) -> RGBA {
        let base = saturation(pair.fill) >= saturation(pair.outline) ? pair.fill : pair.outline
        let mix = { (c: Double) in c * 0.55 + 0.45 }
        return RGBA(red: mix(base.red), green: mix(base.green), blue: mix(base.blue))
    }

    /// Sets the highlight to match the pair, saving the user's own color the first time.
    static func apply(for pair: PointerPair) {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: savedKey) == nil {
            defaults.set(current() ?? "", forKey: savedKey)
        }
        let c = tint(for: pair)
        write(String(format: "%.6f %.6f %.6f Other", c.red, c.green, c.blue))
    }

    /// Puts back the color the user had before the option was turned on.
    static func restore() {
        let defaults = UserDefaults.standard
        guard let saved = defaults.string(forKey: savedKey) else { return }
        if saved.isEmpty { _ = DefaultsTool.delete(key, domain: "-g") } else { write(saved) }
        defaults.removeObject(forKey: savedKey)
        notify()
    }

    private static func current() -> String? {
        UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?[key] as? String
    }

    private static func write(_ value: String) {
        CFPreferencesSetValue(key as CFString, value as CFString, kCFPreferencesAnyApplication,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        notify()
    }

    private static func notify() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("AppleColorPreferencesChangedNotification"), object: nil, userInfo: nil,
            deliverImmediately: true)
    }

    private static func saturation(_ c: RGBA) -> Double {
        let high = max(c.red, c.green, c.blue), low = min(c.red, c.green, c.blue)
        return high == 0 ? 0 : (high - low) / high
    }
}
