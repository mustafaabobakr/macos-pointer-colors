import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A button that records modifier keys to hold, like ⌥ or ⌃⌥: press them, then let go.
/// Every key pressed before letting go counts. Esc cancels.
struct HoldKeyRecorder: View {
    let keys: HoldKeys
    let onRecord: (HoldKeys) -> Void

    @State private var isRecording = false
    /// Every key pressed since the first one went down.
    @State private var pressed: HoldKeys = []
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(buttonTitle)
                .appFont(.caption, monospacedDigits: true)
                .frame(minWidth: 110)
        }
        .help(isRecording ? String(localized: "Press ⌘, ⌥, ⌃ or ⇧, alone or together, then let go. Esc cancels.")
                          : String(localized: "Click to choose the keys to hold"))
        .onDisappear(perform: stop)
    }

    private var buttonTitle: String {
        guard isRecording else { return keys.title }
        return pressed.isEmpty ? String(localized: "Press keys…") : pressed.symbols
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        pressed = []
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            if Int(event.keyCode) == kVK_Escape { stop() }
            return
        }
        let held = HoldKeys(flags: event.modifierFlags)
        pressed.formUnion(held)
        guard held.isEmpty, !pressed.isEmpty else { return }
        onRecord(pressed)
        stop()
    }
}
