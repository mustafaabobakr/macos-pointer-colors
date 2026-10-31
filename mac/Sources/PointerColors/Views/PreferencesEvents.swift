import AppKit
import SwiftUI

/// Watches Preferences' own window: the mouse's side buttons go back and forward, and in the
/// search field ↑ and ↓ move through the results and Return opens one.
struct PreferencesEvents: NSViewRepresentable {
    let back: () -> Void
    let forward: () -> Void
    /// Whether the sidebar's search field has the keyboard.
    let isSearchFocused: () -> Bool
    /// Moves the highlighted result by -1 or 1; false when there's nothing to move through.
    let moveResult: (Int) -> Bool
    /// Opens the highlighted result; false when there's none.
    let openResult: () -> Bool

    func makeNSView(context: Context) -> WatcherView {
        WatcherView()
    }

    func updateNSView(_ view: WatcherView, context: Context) {
        view.handlers = (back, forward, isSearchFocused, moveResult, openResult)
    }

    final class WatcherView: NSView {
        var handlers: (back: () -> Void, forward: () -> Void, isSearchFocused: () -> Bool,
                       moveResult: (Int) -> Bool, openResult: () -> Bool)?
        private var monitor: Any?
        /// Side buttons whose press was taken, so their release is taken too.
        private var takenButtons: Set<Int> = []

        private static let backButton = 3
        private static let forwardButton = 4
        private static let upArrow: UInt16 = 126
        private static let downArrow: UInt16 = 125
        private static let returnKeys: Set<UInt16> = [36, 76]

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .otherMouseUp, .keyDown]) { [weak self] event in
                // Local monitors run on the main thread, with the event the window is about to get.
                nonisolated(unsafe) let event = event
                let used = MainActor.assumeIsolated { self?.uses(event) ?? false }
                return used ? nil : event
            }
        }

        override func removeFromSuperview() {
            removeMonitor()
            super.removeFromSuperview()
        }

        private func removeMonitor() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// Whether Preferences used the event, so the window shouldn't get it.
        private func uses(_ event: NSEvent) -> Bool {
            guard let window, event.window === window, window.attachedSheet == nil else { return false }
            switch event.type {
            case .otherMouseDown: return sideButtonDown(event)
            case .otherMouseUp: return takenButtons.remove(event.buttonNumber) != nil
            case .keyDown: return searchKey(event)
            default: return false
            }
        }

        private func sideButtonDown(_ event: NSEvent) -> Bool {
            switch event.buttonNumber {
            case Self.backButton: handlers?.back()
            case Self.forwardButton: handlers?.forward()
            default: return false
            }
            takenButtons.insert(event.buttonNumber)
            return true
        }

        private func searchKey(_ event: NSEvent) -> Bool {
            guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  let editor = window?.firstResponder as? NSTextView, !editor.hasMarkedText(),
                  let handlers, handlers.isSearchFocused() else { return false }
            if Self.returnKeys.contains(event.keyCode) { return handlers.openResult() }
            let delta = event.keyCode == Self.upArrow ? -1 : event.keyCode == Self.downArrow ? 1 : 0
            return delta != 0 && handlers.moveResult(delta)
        }
    }
}
