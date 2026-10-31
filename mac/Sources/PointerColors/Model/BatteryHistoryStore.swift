import Foundation

/// The battery history in its own file, `~/Library/Application Support/<bundle id>/battery-history.json`.
/// An update replaces only the app, so the history stays through every update and reinstall.
///
/// Before 0.5.1 it lived in the app's defaults under `batteryHistory`. A value there, from an
/// older version, an import or the feature clips' demo settings, moves into the file the next time
/// it's loaded. A file that can't be read is set aside under another name, never written over.
struct BatteryHistoryStore {
    static let defaultsKey = "batteryHistory"

    let fileURL: URL
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard, folder: URL = Self.defaultFolder) {
        self.defaults = defaults
        fileURL = folder.appending(path: "battery-history.json")
    }

    /// The app's folder in Application Support. A bare build has no bundle identifier and gets a
    /// folder of its own, so recording clips never touches the installed app's history.
    static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: Bundle.main.bundleIdentifier ?? "PointerColors",
                                                  directoryHint: .isDirectory)
    }

    func load() -> BatteryHistory {
        moveFromDefaults()
        guard let data else { return BatteryHistory() }
        if let history = try? Self.decoder.decode(BatteryHistory.self, from: data) { return history }
        setAside()
        return BatteryHistory()
    }

    func save(_ history: BatteryHistory) {
        guard let data = try? Self.encoder.encode(history) else { return }
        write(data)
    }

    /// The file as saved, for a settings export.
    var data: Data? { try? Data(contentsOf: fileURL) }

    @discardableResult
    private func write(_ data: Data) -> Bool {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Takes the history out of the defaults only once the file holds it.
    private func moveFromDefaults() {
        guard let data = defaults.data(forKey: Self.defaultsKey), write(data) else { return }
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func setAside() {
        let stamp = Int(Date.now.timeIntervalSince1970)
        let aside = fileURL.deletingLastPathComponent().appending(path: "battery-history-unreadable-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: aside)
    }

    /// Dates as ISO 8601, so the file reads plainly.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
