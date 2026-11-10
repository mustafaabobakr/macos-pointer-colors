import Foundation

/// Whether the app's icon is in the menu bar. Hidden, opening the app again shows Preferences.
enum MenuBarVisibility: String, CaseIterable, Identifiable {
    case always
    case never

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always: return String(localized: "Always")
        case .never: return String(localized: "Never")
        }
    }
}

/// When the mouse's battery shows: in the menu bar, on the Dock icon or under the pointer.
enum BatteryDisplay: String, CaseIterable, Identifiable {
    case off
    /// Below the shared low level, `BatterySettings.lowLevel`.
    case whenLow
    case always

    var id: String { rawValue }

    /// The defaults keys of the three places it shows.
    static let keys = ["batteryDisplay", "dockBattery", "pointerBattery"]

    /// Reads a stored choice, including Below 10% and Below 20% from earlier builds.
    init?(stored raw: String) {
        switch raw {
        case "below10", "below20": self = .whenLow
        default: self.init(rawValue: raw)
        }
    }

    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .whenLow: return String(localized: "When low")
        case .always: return String(localized: "Always show")
        }
    }

    /// Whether a battery at `level` percent is shown, when low means below `low`.
    func shows(_ level: Int?, low: Int) -> Bool {
        guard let level else { return false }
        switch self {
        case .off: return false
        case .whenLow: return level < low
        case .always: return true
        }
    }
}
