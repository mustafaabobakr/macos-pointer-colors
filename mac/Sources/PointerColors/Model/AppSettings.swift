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
        static let lastAppliedPairID = "lastAppliedPairID"
        static let lastAppliedScale = "lastAppliedScale"
    }
}
