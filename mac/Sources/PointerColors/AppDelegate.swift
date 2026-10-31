import AppKit
import SwiftUI

/// Owns the model so links opened from the website reach the same state the menu shows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.applyDockVisibility()
        MenuBarItem.setVisible(model.menuBarVisibility == .always)
        if let path = ScreenshotRenderer.requestedPath {
            ScreenshotRenderer.render(model: model, to: path)
        } else if let request = FeatureClipRecorder.request {
            FeatureClipRecorder.record(request, model: model)
        }
    }

    /// Opening the app again (from Finder, Spotlight or the Dock) shows Preferences, the only way
    /// in while the menu-bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        PreferencesWindow.shared.show(model: model)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.endPointerPress()
        model.installPendingUpdateAtQuit()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.compactMap(PairLink.init(url:)).forEach(confirm)
    }

    /// Links come from outside, so nothing is applied without the user saying so.
    private func confirm(_ link: PairLink) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Add “\(link.name)” to Pointer Colors?")
        alert.informativeText = String(localized: "Outline \(link.outline.hex), fill \(link.fill.hex).")
        alert.addButton(withTitle: String(localized: "Add and Apply"))
        alert.addButton(withTitle: String(localized: "Add"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn: model.add(link, apply: true)
        case .alertSecondButtonReturn: model.add(link, apply: false)
        default: break
        }
    }
}
