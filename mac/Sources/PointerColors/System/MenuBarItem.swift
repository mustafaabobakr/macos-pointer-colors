import AppKit

/// Shows or hides the menu-bar icon that SwiftUI's MenuBarExtra puts up, through its NSStatusItem.
/// SwiftUI shows the item again whenever it updates the scene, so it's hidden again each time.
@MainActor
enum MenuBarItem {
    private static var isHidden = false
    private static var observation: NSKeyValueObservation?

    /// Waits for SwiftUI to create the item when it isn't up yet, as at launch.
    static func setVisible(_ visible: Bool, attempts: Int = 20) {
        isHidden = !visible
        guard let item = statusItem() else {
            guard attempts > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { setVisible(visible, attempts: attempts - 1) }
            return
        }
        observe(item)
        item.isVisible = visible
    }

    private static func observe(_ item: NSStatusItem) {
        guard observation == nil else { return }
        observation = item.observe(\.isVisible) { item, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { if isHidden && item.isVisible { item.isVisible = false } }
            }
        }
    }

    /// The app's one status item, read off the window AppKit draws it in.
    private static func statusItem() -> NSStatusItem? {
        NSApp.windows.lazy
            .filter { String(describing: type(of: $0)) == "NSStatusBarWindow" }
            .compactMap { $0.value(forKey: "statusItem") as? NSStatusItem }
            .first
    }
}
