import AppKit
import CoreGraphics

/// Screen Recording, which laser screenshots need. macOS asks once; after a refusal only System
/// Settings can allow it.
enum ScreenRecordingAccess {
    static var isAllowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows macOS's prompt the first time; when it was refused before, opens System Settings instead.
    @MainActor static func request() {
        guard !isAllowed, !CGRequestScreenCaptureAccess() else { return }
        openSettings()
    }

    @MainActor static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}
