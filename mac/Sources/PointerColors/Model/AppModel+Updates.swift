import AppKit

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
        case .upToDate: return String(localized: "You're up to date.")
        case .available(let version, _): return String(localized: "Version \(version) is available.")
        case .noReleases: return String(localized: "No releases are published yet.")
        case .failed(let reason): return String(localized: "Couldn't check: \(reason)")
        }
    }

    var availableUpdateURL: URL? {
        if case .available(_, let url) = updateResult { return url }
        return nil
    }
}

extension AppModel {
    /// Relaunches the app, e.g. after granting Full Disk Access (which only applies to a fresh process).
    func restartApp() {
        let path = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait until this process has exited, then open the bundle again.
        task.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; open \"$0\"", path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
