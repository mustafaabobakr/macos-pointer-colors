import Foundation

/// When a notification says the mouse's battery is low.
enum BatteryAlert: String, CaseIterable, Identifiable {
    case off
    case below5
    case below10
    case below20

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .below5: return String(localized: "Below 5%")
        case .below10: return String(localized: "Below 10%")
        case .below20: return String(localized: "Below 20%")
        }
    }

    /// The level the battery has to fall below; nil when off.
    var threshold: Int? {
        switch self {
        case .off: return nil
        case .below5: return 5
        case .below10: return 10
        case .below20: return 20
        }
    }
}
