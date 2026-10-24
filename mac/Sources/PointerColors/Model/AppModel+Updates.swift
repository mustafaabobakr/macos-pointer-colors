import AppKit

extension AppModel {
    private static let lastUpdateCheckKey = "lastUpdateCheck"
    /// How often the background check runs while the app is open.
    private static let scheduleTick: TimeInterval = 60 * 60

    var updateSchedule: UpdateSchedule {
        get { UpdateSchedule.saved() }
        set { newValue.save(); Task { await checkForUpdatesIfDue() } }
    }

    private var lastCheckDate: Date? {
        UserDefaults.standard.object(forKey: Self.lastUpdateCheckKey) as? Date
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

    /// Checks when the chosen schedule says the last check is too old.
    func checkForUpdatesIfDue() async {
        guard !isCheckingForUpdates, updateSchedule.isDue(lastCheck: lastCheckDate) else { return }
        await checkForUpdates()
    }

    /// Checks at launch, then every hour whether a scheduled check is due, for as long as the app runs.
    func startUpdateSchedule() {
        Task { await checkForUpdatesIfDue() }
        Timer.scheduledTimer(withTimeInterval: Self.scheduleTick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = Task { await self?.checkForUpdatesIfDue() } }
        }
    }

    /// Opening the menu shows the last result without asking GitHub, unless a scheduled check is due.
    func menuOpened() {
        guard !isCheckingForUpdates, !isInstallingUpdate else { return }
        if let recent = recentUpdateCheck { updateResult = recent }
        Task { await checkForUpdatesIfDue() }
    }

    /// Closing the menu clears its update status, such as "You're up to date". An available
    /// update stays, so the menu still offers it next time.
    func menuClosed() {
        guard !isInstallingUpdate, availableUpdateURL == nil else { return }
        updateResult = nil
        updateInstallError = nil
    }

    /// The last successful check from this run, to show again when the menu opens.
    private var recentUpdateCheck: UpdateChecker.Result? {
        guard let last = lastUpdateCheck else { return nil }
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

    /// The update row's second line in the menu: the latest status, or the version when there's
    /// nothing to report.
    var menuUpdateLine: String {
        updateMessage ?? String(localized: "Version \(UpdateChecker().currentVersion)")
    }

    var updateMessage: String? {
        if isInstallingUpdate { return String(localized: "Installing the update…") }
        if let updateInstallError { return String(localized: "Couldn't install: \(updateInstallError)") }
        switch updateResult {
        case .none: return nil
        case .upToDate: return String(localized: "You're up to date (\(UpdateChecker().currentVersion)).")
        case .available(let version, _, _, _): return String(localized: "Version \(version) is available.")
        case .noReleases: return String(localized: "No releases are published yet.")
        case .failed(let reason): return String(localized: "Couldn't check: \(reason)")
        }
    }

    var availableUpdateURL: URL? {
        if case .available(_, let url, _, _) = updateResult { return url }
        return nil
    }

    var availableUpdateDownload: URL? {
        if case .available(_, _, let download, _) = updateResult { return download }
        return nil
    }

    /// What changed in the available version, for the menu and Preferences.
    var availableUpdateNotes: (version: String, notes: String)? {
        guard case .available(let version, _, _, let notes?) = updateResult else { return nil }
        return (version, notes)
    }
}
