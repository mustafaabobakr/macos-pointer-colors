import Foundation

/// Which build is running, as build-app.sh stamped it into Info.plist from mac/.env.local or
/// mac/.env.prod. A build without the stamp, like `swift run`, counts as local.
struct BuildInfo {
    let isLocal: Bool
    /// The short commit, with "-dirty" when there were uncommitted changes.
    let commit: String?
    let date: Date?

    static let current = BuildInfo(info: Bundle.main.infoDictionary ?? [:])

    init(info: [String: Any]) {
        // Feature screenshots are taken with a bare build, and show the app as people get it.
        isLocal = info["PCBuildChannel"] as? String != "release" && !ScreenshotRenderer.isRendering
        commit = info["PCBuildCommit"] as? String
        date = (info["PCBuildDate"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    /// "Local build · 3e4da7f-dirty · Oct 25, 22:24", or nil for a release.
    var localLabel: String? {
        guard isLocal else { return nil }
        let when = date?.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        return ([String(localized: "Local build")] + [commit, when].compactMap { $0 }).joined(separator: " · ")
    }
}
