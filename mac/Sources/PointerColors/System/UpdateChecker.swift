import Foundation

/// Compares the running version with the latest GitHub release of the repo.
struct UpdateChecker {
    enum Result: Equatable {
        case upToDate
        case available(version: String, url: URL)
        case noReleases
        case failed(String)
    }

    static let latestReleaseURL = URL(string: "https://api.github.com/repos/mustafaabobakr/macos-pointer-colors/releases/latest")!

    var session: URLSession = .shared

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    func check() async -> Result {
        var request = URLRequest(url: Self.latestReleaseURL)
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
        guard status == 200 else { return .failed("GitHub answered \(status).") }
        guard let release = try? JSONDecoder().decode(Release.self, from: data),
              let url = URL(string: release.htmlURL) else { return .failed("Couldn't read the release.") }
        let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        return isNewer(latest, than: current) ? .available(version: latest, url: url) : .upToDate
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

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
