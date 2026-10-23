import Foundation

extension AppModel {
    private static let lastUpdateCheckKey = "lastUpdateCheck"
    private static let autoCheckKey = "checkForUpdatesAutomatically"

    /// Off by default: the app only contacts GitHub when the user asks or turns this on.
    var checksForUpdatesAutomatically: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoCheckKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoCheckKey) }
    }

    func checkForUpdates() async {
        isCheckingForUpdates = true
        updateResult = await UpdateChecker().check()
        isCheckingForUpdates = false
        UserDefaults.standard.set(Date(), forKey: Self.lastUpdateCheckKey)
    }

    /// At most once a day, and only when automatic checks are on.
    func checkForUpdatesIfDue() async {
        guard checksForUpdatesAutomatically else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastUpdateCheckKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > 24 * 60 * 60 else { return }
        await checkForUpdates()
    }

    var updateMessage: String? {
        switch updateResult {
        case .none: return nil
        case .upToDate: return "You're up to date."
        case .available(let version, _): return "Version \(version) is available."
        case .noReleases: return "No releases are published yet."
        case .failed(let reason): return "Couldn't check: \(reason)"
        }
    }

    var availableUpdateURL: URL? {
        if case .available(_, let url) = updateResult { return url }
        return nil
    }
}
