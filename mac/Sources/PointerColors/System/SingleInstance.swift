import AppKit

/// Keeps one Pointer Colors running. The copy opened last wins, so opening a newer copy (an
/// update, a build, another folder) replaces the one already in the menu bar rather than adding
/// a second icon, pointer colors and click handling next to it.
@MainActor
enum SingleInstance {
    /// Seconds a copy gets to quit on its own before it's stopped.
    private static let graceTime = 3.0

    /// Asks every other running copy to quit. Screenshot and clip renders run beside the
    /// user's copy on purpose, so they leave it alone.
    static func quitOtherCopies() {
        guard !ScreenshotRenderer.isRendering, let bundleID = Bundle.main.bundleIdentifier else { return }
        let others = otherCopies(of: bundleID)
        guard !others.isEmpty else { return }
        others.forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + graceTime) {
            others.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
        }
    }

    private static func otherCopies(of bundleID: String) -> [NSRunningApplication] {
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != me }
    }
}
