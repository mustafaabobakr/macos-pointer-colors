import Foundation

/// How often the app checks GitHub for a new version on its own.
enum UpdateSchedule: String, CaseIterable, Identifiable {
    case off, daily, weekly, monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return String(localized: "Never")
        case .daily: return String(localized: "Every day")
        case .weekly: return String(localized: "Every week")
        case .monthly: return String(localized: "Every month")
        }
    }

    /// Nil when automatic checks are off.
    var interval: TimeInterval? {
        let day: TimeInterval = 24 * 60 * 60
        switch self {
        case .off: return nil
        case .daily: return day
        case .weekly: return 7 * day
        case .monthly: return 30 * day
        }
    }

    /// True when a check that happened at `last` is older than this schedule allows.
    func isDue(lastCheck last: Date?, now: Date = Date()) -> Bool {
        guard let interval else { return false }
        guard let last else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    private static let key = "updateSchedule"
    /// The switch this schedule replaced: on meant daily.
    private static let legacyKey = "checkForUpdatesAutomatically"

    /// Daily unless chosen otherwise, since the menu used to check every time it opened.
    static func saved(in defaults: UserDefaults = .standard) -> UpdateSchedule {
        defaults.string(forKey: key).flatMap(UpdateSchedule.init(rawValue:)) ?? .daily
    }

    func save(in defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.key)
        defaults.removeObject(forKey: Self.legacyKey)
    }
}
