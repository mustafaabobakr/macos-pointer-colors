import Foundation

/// Every app preference in one file: pairs, automation, highlight, speed, shortcuts and appearance.
/// Reads and writes the app's own UserDefaults domain, leaving out what macOS keeps there for
/// windows and panels and what only describes this Mac's update checks. Launch at login, which
/// macOS keeps instead of the app, goes in the file next to them.
struct SettingsBackup {
    private let defaults: UserDefaults
    private let domain: String

    private static let format = "pointer-colors-settings"
    private static let version = 1
    private static let skippedPrefixes = ["NS", "com_apple_", "Apple"]
    private static let skippedKeys: Set<String> = ["lastUpdateCheck", "updateFeedURL"]

    enum Failure: LocalizedError {
        case notABackup

        var errorDescription: String? {
            String(localized: "This isn't a Pointer Colors settings file.")
        }
    }

    init(defaults: UserDefaults = .standard, domain: String = Bundle.main.bundleIdentifier ?? "PointerColors") {
        self.defaults = defaults
        self.domain = domain
    }

    func export(launchAtLogin: Bool) throws -> Data {
        let file: [String: Any] = ["format": Self.format, "version": Self.version, "settings": storedSettings(),
                                   "launchAtLogin": launchAtLogin]
        return try PropertyListSerialization.data(fromPropertyList: file, format: .xml, options: 0)
    }

    /// Replaces every backed-up preference with the file's. Takes effect after a relaunch.
    /// Returns the file's Launch at login for the caller to apply; nil in files from before it was saved.
    @discardableResult
    func restore(from data: Data) throws -> Bool? {
        let file = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        guard file?["format"] as? String == Self.format, let settings = file?["settings"] as? [String: Any] else {
            throw Failure.notABackup
        }
        for key in storedSettings().keys { defaults.removeObject(forKey: key) }
        for (key, value) in settings where Self.isBackedUp(key) { defaults.set(value, forKey: key) }
        return file?["launchAtLogin"] as? Bool
    }

    private func storedSettings() -> [String: Any] {
        (defaults.persistentDomain(forName: domain) ?? [:]).filter { Self.isBackedUp($0.key) }
    }

    private static func isBackedUp(_ key: String) -> Bool {
        !skippedKeys.contains(key) && !skippedPrefixes.contains { key.hasPrefix($0) }
    }
}
