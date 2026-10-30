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

/// When the mouse's battery shows next to the menu-bar icon.
enum BatteryDisplay: String, CaseIterable, Identifiable {
    case off
    case below10
    case below20
    case always

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .below10: return String(localized: "Below 10%")
        case .below20: return String(localized: "Below 20%")
        case .always: return String(localized: "Always show")
        }
    }

    /// Whether a battery at `level` percent is shown.
    func shows(_ level: Int?) -> Bool {
        guard let level else { return false }
        switch self {
        case .off: return false
        case .below10: return level < 10
        case .below20: return level < 20
        case .always: return true
        }
    }
}
