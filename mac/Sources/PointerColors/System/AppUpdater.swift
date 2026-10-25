import Foundation
import Security

/// Installs a new version in place from the release DMG, then relaunches.
///
/// The app isn't notarized, so a copy downloaded in a browser is marked as coming from the internet
/// and Gatekeeper asks again for every new version. A file this app downloads itself carries no such
/// mark, so the swapped-in version opens without the prompt. In exchange, the new app must be signed
/// by the same certificate as the running one, so a tampered download can't replace it.
enum AppUpdater {
    enum Failure: LocalizedError, Equatable {
        case commandFailed(String)
        case noAppInImage
        case signatureMismatch
        /// Running from the DMG, or from the read-only copy macOS makes of an app opened outside
        /// Applications before it's been moved.
        case notInstalled
        case folderNotWritable

        var errorDescription: String? {
            switch self {
            case .commandFailed(let command):
                return String(localized: "\(command) failed.")
            case .noAppInImage:
                return String(localized: "The download doesn't contain the app.")
            case .signatureMismatch:
                return String(localized: "The download isn't signed like this app, so it wasn't installed.")
            case .notInstalled:
                return String(localized: "Move Pointer Colors to Applications, open it from there, then try again.")
            case .folderNotWritable:
                return String(localized: "Pointer Colors can't replace itself in this folder.")
            }
        }
    }

    /// Downloads the DMG, checks the app inside and swaps it in for the app at `appURL`.
    static func install(from dmgURL: URL, replacing appURL: URL = Bundle.main.bundleURL) async throws {
        try finish(try await prepare(from: dmgURL, replacing: appURL), replacing: appURL)
    }

    /// Downloads the DMG, checks the app inside and copies it next to the app at `appURL`, ready
    /// for `finish`. Slow, so it runs before the swap, which is quick enough to do at quit.
    static func prepare(from dmgURL: URL, replacing appURL: URL = Bundle.main.bundleURL) async throws -> URL {
        if let blocker = installBlocker(for: appURL) { throw blocker }
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent("PointerColorsUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let dmg = try await download(dmgURL, into: workDir)
        let mountPoint = workDir.appendingPathComponent("image")
        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mountPoint.path])
        defer { try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"]) }

        let newApp = try appInImage(at: mountPoint)
        guard try isSignedLikeThisApp(newApp) else { throw Failure.signatureMismatch }
        return try stage(newApp, next: appURL)
    }

    /// Swaps a prepared copy in for the app at `appURL` in one step.
    static func finish(_ staged: URL, replacing appURL: URL = Bundle.main.bundleURL) throws {
        do {
            _ = try FileManager.default.replaceItemAt(appURL, withItemAt: staged)
        } catch {
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
    }

    /// Why the app at `appURL` can't replace itself, checked before anything is downloaded.
    static func installBlocker(for appURL: URL = Bundle.main.bundleURL) -> Failure? {
        if appURL.path.contains("/AppTranslocation/") { return .notInstalled }
        let values = try? appURL.resourceValues(forKeys: [.volumeIsReadOnlyKey])
        if values?.volumeIsReadOnly == true { return .notInstalled }
        let folder = appURL.deletingLastPathComponent().path
        return FileManager.default.isWritableFile(atPath: folder) ? nil : .folderNotWritable
    }

    /// Opens the app at `appURL` once this process has quit. Call it, then terminate.
    static func relaunch(_ appURL: URL = Bundle.main.bundleURL) throws {
        let script = #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; /usr/bin/open "$2""#
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), appURL.path]
        try process.run()
    }

    // MARK: Steps

    private static func download(_ url: URL, into directory: URL) async throws -> URL {
        let (temporary, response) = try await URLSession.shared.download(from: url)
        if let status = (response as? HTTPURLResponse)?.statusCode, status != 200 {
            throw Failure.commandFailed(String(localized: "Download (\(status))"))
        }
        let destination = directory.appendingPathComponent("Pointer-Colors.dmg")
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private static func appInImage(at mountPoint: URL) throws -> URL {
        let items = try FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)
        guard let app = items.first(where: { $0.pathExtension == "app" }) else { throw Failure.noAppInImage }
        return app
    }

    /// True when `app` is validly signed and meets this app's designated requirement: the same
    /// bundle id, signed by the same certificate.
    private static func isSignedLikeThisApp(_ app: URL) throws -> Bool {
        var running: SecCode?
        var me: SecStaticCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard SecCodeCopySelf([], &running) == errSecSuccess, let running,
              SecCodeCopyStaticCode(running, [], &me) == errSecSuccess, let me,
              SecCodeCopyDesignatedRequirement(me, [], &requirement) == errSecSuccess, let requirement,
              SecStaticCodeCreateWithPath(app as CFURL, [], &candidate) == errSecSuccess, let candidate else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(candidate, flags, requirement) == errSecSuccess
    }

    /// Copies the new app next to the old one, so the swap is a single rename and a failure part
    /// way leaves the old app in place.
    private static func stage(_ newApp: URL, next appURL: URL) throws -> URL {
        let staged = appURL.deletingLastPathComponent().appendingPathComponent(".\(appURL.lastPathComponent).update")
        try? FileManager.default.removeItem(at: staged)
        try run("/usr/bin/ditto", [newApp.path, staged.path])
        // Nothing should carry the internet mark, but a leftover one would bring the prompt back.
        try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
        return staged
    }

    private static func run(_ path: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw Failure.commandFailed(URL(fileURLWithPath: path).lastPathComponent)
        }
    }
}
