import Foundation

/// Compares the running version with the latest GitHub release of the repo.
struct UpdateChecker {
    enum Result: Equatable {
        case upToDate
        /// `download` is the release's DMG, when it has one, for installing in place. `notes` is
        /// what changed, from the release notes.
        case available(version: String, url: URL, download: URL?, notes: String?)
        case noReleases
        case failed(String)
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/mustafaabobakr/macos-pointer-colors/releases/latest")!
    /// The release file the updater installs from.
    static let dmgName = "Pointer-Colors.dmg"

    /// The GitHub release, unless the `updateFeedURL` default points somewhere else, which is how
    /// an update is tried out from a local server before it's published.
    static var feedURL: URL {
        UserDefaults.standard.string(forKey: "updateFeedURL").flatMap(URL.init(string:)) ?? latestReleaseURL
    }

    var session: URLSession = .shared

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check() async -> Result {
        var request = URLRequest(url: Self.feedURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            return Self.result(data: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0, current: currentVersion)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Pure decision logic, split out so it can be tested without the network.
    static func result(data: Data, status: Int, current: String) -> Result {
        if status == 404 { return .noReleases }
        guard status == 200 else { return .failed(String(localized: "GitHub answered \(status).")) }
        guard let release = try? JSONDecoder().decode(Release.self, from: data),
              let url = URL(string: release.htmlURL) else { return .failed("Couldn't read the release.") }
        let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        guard isNewer(latest, than: current) else { return .upToDate }
        let download = release.assets.first { $0.name == dmgName }.flatMap { URL(string: $0.downloadURL) }
        return .available(version: latest, url: url, download: download, notes: whatsNew(in: release.body))
    }

    /// The part of the release notes about what changed: everything before the install
    /// instructions, which start at "**Updating from" or "**Install:**" in every release.
    /// Screenshot lines are dropped, since the app shows the notes as text.
    static func whatsNew(in body: String?) -> String? {
        guard let body else { return nil }
        let cut = ["**Updating from", "**Install:**"].compactMap { body.range(of: $0)?.lowerBound }.min()
        let notes = String(body[..<(cut ?? body.endIndex)])
            .replacingOccurrences(of: #"\n+[ \t]*!\[[^\]]*\]\([^)]*\)[ \t]*(?=\n|$)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? nil : notes
    }

    /// Numeric, part by part: 0.10.0 is newer than 0.9.3.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let (x, y) = (index < a.count ? a[index] : 0, index < b.count ? b[index] : 0)
            if x != y { return x > y }
        }
        return false
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: String
        let body: String?
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case body
            case assets
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tagName = try container.decode(String.self, forKey: .tagName)
            htmlURL = try container.decode(String.self, forKey: .htmlURL)
            body = try container.decodeIfPresent(String.self, forKey: .body)
            assets = try container.decodeIfPresent([Asset].self, forKey: .assets) ?? []
        }
    }

    private struct Asset: Decodable {
        let name: String
        let downloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }
}
