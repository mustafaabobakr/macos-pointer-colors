import AppKit

/// The app's own folder for laser screenshots that aren't saved anywhere else: those only opened
/// in an app. They stay here until removed from Preferences.
struct LaserShotStore {
    let folder: URL

    init(folder: URL = BatteryHistoryStore.defaultFolder.appending(path: "Screenshots", directoryHint: .isDirectory)) {
        self.folder = folder
    }

    /// The PNGs in the folder; none when it doesn't exist yet.
    var files: [URL] {
        let found = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey],
                                                                  options: .skipsHiddenFiles)
        return (found ?? []).filter { $0.pathExtension.lowercased() == "png" }
    }

    /// How many screenshots there are and how many bytes they take.
    var usage: (count: Int, bytes: Int) {
        let sizes = files.map { (try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0 }
        return (sizes.count, sizes.reduce(0, +))
    }

    /// Makes the folder if needed and returns it, ready to save into.
    func prepared() throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Opens the folder in Finder, making it first so there's always something to show.
    @MainActor func showInFinder() {
        guard let folder = try? prepared() else { return }
        NSWorkspace.shared.open(folder)
    }

    /// Deletes every screenshot for good: not to the Trash. Stops at the first file that can't go.
    func deleteAll() throws {
        for file in files { try FileManager.default.removeItem(at: file) }
    }
}
