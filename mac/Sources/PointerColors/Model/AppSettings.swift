import Foundation
import ServiceManagement

/// The app's own preferences (not the system pointer settings).
struct AppSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.reapplyAtLaunch: true, Key.iconInPairColors: true])
    }

    /// Puts the last applied pair and size back when the app starts.
    var reapplyAtLaunch: Bool {
        get { defaults.bool(forKey: Key.reapplyAtLaunch) }
        nonmutating set { defaults.set(newValue, forKey: Key.reapplyAtLaunch) }
    }

    /// Off shows a monochrome template icon in the menu bar.
    var iconInPairColors: Bool {
        get { defaults.bool(forKey: Key.iconInPairColors) }
        nonmutating set { defaults.set(newValue, forKey: Key.iconInPairColors) }
    }

    var playSoundOnApply: Bool {
        get { defaults.bool(forKey: Key.playSoundOnApply) }
        nonmutating set { defaults.set(newValue, forKey: Key.playSoundOnApply) }
    }

    var textSize: TextSize {
        get { defaults.string(forKey: Key.textSize).flatMap(TextSize.init(rawValue:)) ?? .automatic }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.textSize) }
    }

    /// Recorded global shortcuts. Empty by default: nothing is assigned until the user records one.
    var shortcuts: [ShortcutAction: KeyCombo] {
        get {
            guard let data = defaults.data(forKey: Key.shortcuts),
                  let raw = try? JSONDecoder().decode([String: KeyCombo].self, from: data) else { return [:] }
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, combo in
                ShortcutAction(rawValue: key).map { ($0, combo) }
            })
        }
        nonmutating set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            defaults.set(try? JSONEncoder().encode(raw), forKey: Key.shortcuts)
        }
    }

    var lastAppliedPairID: String? {
        get { defaults.string(forKey: Key.lastAppliedPairID) }
        nonmutating set { defaults.set(newValue, forKey: Key.lastAppliedPairID) }
    }

    var lastAppliedScale: Double? {
        get { defaults.object(forKey: Key.lastAppliedScale) as? Double }
        nonmutating set { defaults.set(newValue, forKey: Key.lastAppliedScale) }
    }

    /// Launch at login through the system's login items. Only works from the bundled .app.
    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    private enum Key {
        static let reapplyAtLaunch = "reapplyAtLaunch"
        static let iconInPairColors = "iconInPairColors"
        static let playSoundOnApply = "playSoundOnApply"
        static let textSize = "textSize"
        static let shortcuts = "shortcuts"
        static let lastAppliedPairID = "lastAppliedPairID"
        static let lastAppliedScale = "lastAppliedScale"
    }
}
