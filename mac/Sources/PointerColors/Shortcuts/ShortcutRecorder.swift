import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A button that records the next key press as a shortcut.
/// Esc cancels, Delete clears, and a combo needs ⌘, ⌥ or ⌃.
struct ShortcutRecorder: View {
    let combo: KeyCombo?
    let onRecord: (KeyCombo?) -> Void
    /// Called with true while recording so existing hotkeys can be paused.
    var onRecordingChange: (Bool) -> Void = { _ in }

    @State private var isRecording = false
    @State private var hint: String?
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(buttonTitle)
                    .appFont(.caption, monospacedDigits: true)
                    .frame(minWidth: 110)
            }
            .help(isRecording ? "Press a shortcut. Esc cancels, Delete clears." : "Click to record a shortcut")
            if combo != nil && !isRecording {
                Button { onRecord(nil) } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear shortcut")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let hint { Text(hint).appFont(.caption2).foregroundStyle(.orange).offset(y: 16) }
        }
        .onDisappear(perform: stop)
    }

    private var buttonTitle: String {
        if isRecording { return "Type shortcut…" }
        return combo?.displayString ?? "Record shortcut"
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        hint = nil
        onRecordingChange(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        onRecordingChange(false)
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            stop()
        case kVK_Delete, kVK_ForwardDelete:
            onRecord(nil)
            stop()
        default:
            record(event)
        }
    }

    private func record(_ event: NSEvent) {
        guard let combo = KeyCombo(event: event) else {
            hint = "Include ⌘, ⌥ or ⌃"
            return
        }
        hint = nil
        onRecord(combo)
        stop()
    }
}
