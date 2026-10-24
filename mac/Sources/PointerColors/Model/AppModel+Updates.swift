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
        updateInstallError = nil
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
