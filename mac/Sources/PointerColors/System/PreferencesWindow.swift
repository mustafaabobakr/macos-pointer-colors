import AppKit
import SwiftUI

/// The one Preferences window. The menu, an app's icon in the menu, and opening the app again
/// all bring this same window forward, so there's never a second one.
@MainActor
final class PreferencesWindow {
    static let shared = PreferencesWindow()
    private var window: NSWindow?

    private init() {}

    func show(model: AppModel) {
        let window = window ?? make(model: model)
        self.window = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func make(model: AppModel) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(model: model)))
        window.title = String(localized: "Preferences")
        window.styleMask.insert(.resizable)
        window.toolbarStyle = .unified
        // Closing keeps it, so the next open is the same window, where it was left.
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Preferences")
        return window
    }
}
