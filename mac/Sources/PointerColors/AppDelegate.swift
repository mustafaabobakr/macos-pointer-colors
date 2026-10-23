import AppKit

/// Owns the model so links opened from the website reach the same state the menu shows.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.compactMap(PairLink.init(url:)).forEach(confirm)
    }

    /// Links come from outside, so nothing is applied without the user saying so.
    private func confirm(_ link: PairLink) {
        let alert = NSAlert()
        alert.messageText = "Add “\(link.name)” to Pointer Colors?"
        alert.informativeText = "Outline \(link.outline.hex), fill \(link.fill.hex)."
        alert.addButton(withTitle: "Add and Apply")
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        switch alert.runModal() {
        case .alertFirstButtonReturn: model.add(link, apply: true)
        case .alertSecondButtonReturn: model.add(link, apply: false)
        default: break
        }
    }
}
