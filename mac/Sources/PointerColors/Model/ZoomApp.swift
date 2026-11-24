import Foundation

/// An app where a Magic Mouse double tap is left to macOS's own Smart Zoom.
struct ZoomApp: Codable, Identifiable, Equatable {
    var bundleID: String
    var name: String
    /// Off keeps the app in the list while Pointer Colors zooms over it as over any other app.
    var isOn = true

    var id: String { bundleID }

    /// The apps the list starts with, which the user picked.
    static let defaults = [
        ZoomApp(bundleID: "com.apple.Safari", name: "Safari"),
        ZoomApp(bundleID: "com.google.Chrome", name: "Google Chrome"),
        ZoomApp(bundleID: "com.brave.Browser", name: "Brave Browser"),
        ZoomApp(bundleID: "com.apple.Preview", name: "Preview"),
        ZoomApp(bundleID: "com.apple.Photos", name: "Photos"),
    ]

    init(bundleID: String, name: String) {
        self.bundleID = bundleID
        self.name = name
    }

    init?(url: URL) {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        self.init(bundleID: bundleID, name: name)
    }

    /// Reads lists saved before apps had their own switch as all on.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        name = try container.decode(String.self, forKey: .name)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
    }
}
