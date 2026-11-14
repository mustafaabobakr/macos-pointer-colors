import AppKit

/// System Settings › Mouse › Smart zoom, which makes macOS recognize a Magic Mouse double tap.
enum MacSmartZoomSetting {
    private static let domains = ["com.apple.driver.AppleBluetoothMultitouch.mouse", "com.apple.AppleMultitouchMouse"]
    private static let key = "MouseOneFingerDoubleTapGesture" as CFString

    /// True unless the setting is known to be off.
    static var isOn: Bool {
        let values = domains.compactMap { CFPreferencesCopyAppValue(key, $0 as CFString) as? Int }
        return values.isEmpty || values.contains { $0 != 0 }
    }

    static func openMouseSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Mouse-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
