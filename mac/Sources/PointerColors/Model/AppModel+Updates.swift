import AppKit

extension AppModel {
    private static let lastUpdateCheckKey = "lastUpdateCheck"
    private static let autoCheckKey = "checkForUpdatesAutomatically"
    /// How long a check is reused when the menu opens again. GitHub allows 60 requests an hour.
    private static let menuCheckInterval: TimeInterval = 5 * 60

    /// The daily check in the background, off by default. Opening the menu checks either way.
    var checksForUpdatesAutomatically: Bool {
        get { UserDefaults.standard.bool(forKey: Self.autoCheckKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.autoCheckKey) }
    }

    func checkForUpdates() async {
        isCheckingForUpdates = true
        updateInstallError = nil
        let result = await UpdateChecker().check()
        updateResult = result
        lastUpdateCheck = (Date(), result)
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

    /// Opening the menu checks for updates, reusing a check from the last few minutes.
    func menuOpened() {
        guard !isCheckingForUpdates, !isInstallingUpdate else { return }
        if let recent = recentUpdateCheck {
            updateResult = recent
        } else {
            Task { await checkForUpdates() }
        }
    }

    /// Closing the menu clears its update status, such as "You're up to date". An available
    /// update stays, so the menu still offers it next time.
    func menuClosed() {
        guard !isInstallingUpdate, availableUpdateURL == nil else { return }
        updateResult = nil
        updateInstallError = nil
    }

    /// A successful check recent enough to show again without asking GitHub.
    private var recentUpdateCheck: UpdateChecker.Result? {
        guard let last = lastUpdateCheck, Date().timeIntervalSince(last.date) < Self.menuCheckInterval else { return nil }
        if case .failed = last.result { return nil }
        return last.result
    }

    /// Installs the new version in place and relaunches into it (see AppUpdater).
    func installUpdate() async {
        guard let download = availableUpdateDownload else { return }
        isInstallingUpdate = true
        updateInstallError = nil
        do {
            try await AppUpdater.install(from: download)
            try AppUpdater.relaunch()
            NSApp.terminate(nil)
        } catch {
            updateInstallError = error.localizedDescription
            isInstallingUpdate = false
            // The release page still has the DMG to install by hand.
            if let url = availableUpdateURL { NSWorkspace.shared.open(url) }
        }
    }

    /// The menu's update row: installs when the release has a DMG, opens the release page when it
    /// doesn't, and checks otherwise.
    func performUpdateAction() {
        if availableUpdateDownload != nil {
            Task { await installUpdate() }
        } else if let url = availableUpdateURL {
            NSWorkspace.shared.open(url)
        } else {
            Task { await checkForUpdates() }
        }
    }

    var updateActionTitle: String {
        if isCheckingForUpdates { return String(localized: "Checking for Updates…") }
        if isInstallingUpdate { return String(localized: "Installing Update…") }
        if availableUpdateDownload != nil { return String(localized: "Install Update and Relaunch") }
        return String(localized: "Check for Updates…")
    }

    /// The update message plus what clicking the menu row will do.
    var menuUpdateMessage: String? {
        guard let message = updateMessage else { return nil }
        guard !isInstallingUpdate, updateInstallError == nil else { return message }
        if availableUpdateDownload != nil { return String(localized: "\(message) Click above to install.") }
        if availableUpdateURL != nil { return String(localized: "\(message) Click above to download.") }
        return message
    }

    var updateMessage: String? {
        if isInstallingUpdate { return String(localized: "Installing the update…") }
        if let updateInstallError { return String(localized: "Couldn't install: \(updateInstallError)") }
        switch updateResult {
        case .none: return nil
        case .upToDate: return String(localized: "You're up to date.")
        case .available(let version, _, _): return String(localized: "Version \(version) is available.")
        case .noReleases: return String(localized: "No releases are published yet.")
        case .failed(let reason): return String(localized: "Couldn't check: \(reason)")
        }
    }

    var availableUpdateURL: URL? {
        if case .available(_, let url, _) = updateResult { return url }
        return nil
    }

    var availableUpdateDownload: URL? {
        if case .available(_, _, let download) = updateResult { return download }
        return nil
    }
}
