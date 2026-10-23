import Foundation

/// Writes preferences through Apple's `/usr/bin/defaults`. macOS lets that system tool write
/// `com.apple.universalaccess` even when this app has no Full Disk Access, while a direct
/// CFPreferences write from the app is refused. Used as the fallback for every pointer setting.
enum DefaultsTool {
    private static let path = "/usr/bin/defaults"
    static let universalAccess = "com.apple.universalaccess"

    /// `defaults write <domain> <key> -dict red -float … alpha -float …`
    static func write(_ key: String, color: RGBA, domain: String = universalAccess) -> Bool {
        let channels = color.preferenceValue.sorted { $0.key < $1.key }
            .flatMap { [$0.key, "-float", String($0.value)] }
        return run(["write", domain, key, "-dict"] + channels)
    }

    static func write(_ key: String, number: Double, domain: String = universalAccess) -> Bool {
        run(["write", domain, key, "-float", String(number)])
    }

    static func write(_ key: String, bool: Bool, domain: String) -> Bool {
        run(["write", domain, key, "-bool", bool ? "true" : "false"])
    }

    static func delete(_ key: String, domain: String = universalAccess) -> Bool {
        run(["delete", domain, key])
    }

    /// True when the tool runs and exits cleanly.
    private static func run(_ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
