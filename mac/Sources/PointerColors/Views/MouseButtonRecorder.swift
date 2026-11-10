import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Records a mouse button: click it, then press the button on the mouse. Only buttons other than
/// the left and right ones count; Esc, or a second click, cancels.
struct MouseButtonRecorder: View {
    let title: LocalizedStringKey
    let number: Int64
    let onRecord: (Int64) -> Void

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(buttonTitle)
                .appFont(.caption, monospacedDigits: true)
                .frame(minWidth: 130)
        }
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(buttonTitle))
        .help(isRecording ? String(localized: "Press a button on the mouse. Esc cancels.")
                          : String(localized: "Click, then press the mouse button to use"))
        .onDisappear(perform: stop)
    }

    private var buttonTitle: String {
        isRecording ? String(localized: "Press a mouse button…") : Self.name(of: number)
    }

    /// People count buttons from 1, as the left button; macOS counts from 0.
    static func name(of number: Int64) -> String {
        String(localized: "Button \(number + 1)")
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .keyDown]) { event in
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
        if event.type == .otherMouseDown {
            onRecord(Int64(event.buttonNumber))
            stop()
        } else if Int(event.keyCode) == kVK_Escape {
            stop()
        }
    }
}
