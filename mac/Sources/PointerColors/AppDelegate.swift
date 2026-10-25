import AppKit

/// Owns the model so links opened from the website reach the same state the menu shows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let path = ScreenshotRenderer.requestedPath {
            ScreenshotRenderer.render(model: model, to: path)
        } else if let folder = ScreenshotRenderer.requestedFeaturesFolder {
            ScreenshotRenderer.renderFeatures(model: model, into: folder)
        }
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
