import AppKit
import Observation
import SwiftUI

/// The menu-bar item and its popover, plus the Preferences window.
/// Replaces SwiftUI's MenuBarExtra, which always closes as soon as another window
/// (like Preferences) becomes active. This popover stays open while Preferences is open,
/// and otherwise closes on a click elsewhere or Esc.
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var preferencesWindow: NSWindow?
    private var outsideClickMonitor: Any?

    init(model: AppModel) {
        self.model = model
        super.init()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self
        let root = MenuContentView(model: model)
            .environment(\.openPreferences, OpenPreferencesAction { [weak self] in self?.showPreferences() })
        popover.contentViewController = NSHostingController(rootView: root)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePopover)
        trackIcon()
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        startOutsideClickMonitor()
    }

    /// Closes on clicks in other apps, unless Preferences is open.
    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.preferencesWindow?.isVisible != true else { return }
                self.popover.performClose(nil)
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated { stopOutsideClickMonitor() }
    }

    func showPreferences() {
        let window = preferencesWindow ?? makePreferencesWindow()
        preferencesWindow = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makePreferencesWindow() -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView(model: model)))
        window.title = String(localized: "Pointer Colors Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    /// Redraws the menu-bar icon whenever the applied pair or icon setting changes.
    private func trackIcon() {
        withObservationTracking {
            statusItem.button?.image = MenuBarIcon.image(for: model.menuBarPair, colored: model.iconInPairColors)
        } onChange: { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.trackIcon() } }
        }
    }
}

/// Opens the Preferences window from inside the popover.
struct OpenPreferencesAction {
    let action: () -> Void
    func callAsFunction() { action() }
}

private struct OpenPreferencesKey: EnvironmentKey {
    static let defaultValue = OpenPreferencesAction {}
}

extension EnvironmentValues {
    var openPreferences: OpenPreferencesAction {
        get { self[OpenPreferencesKey.self] }
        set { self[OpenPreferencesKey.self] = newValue }
    }
}
