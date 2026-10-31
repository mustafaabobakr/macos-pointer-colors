import Foundation

/// CHANGELOG.md, bundled with the app, split into its releases for Preferences › What's New.
struct Changelog {
    struct Release: Identifiable, Hashable {
        let version: String
        let date: String?
        /// The release's bullets and paragraphs, each still in Markdown.
        let lines: [Line]
        var id: String { version }
    }

    enum Line: Hashable {
        case bullet(String)
        case paragraph(String)
    }

    let releases: [Release]

    /// The bundled changelog. The bare `swift build`, which feature clips record with, has no
    /// bundle, so it reads the one in the repo it was built from.
    static let bundled: Changelog = {
        let repoCopy = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().appendingPathComponent("../../../../CHANGELOG.md").standardizedFileURL
        let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md") ?? repoCopy
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return Changelog(releases: []) }
        return Changelog(markdown: text)
    }()

    init(releases: [Release]) {
        self.releases = releases
    }

    /// Reads `## 0.4.9 — 2026-10-30` headings and the bullets and paragraphs under each.
    init(markdown: String) {
        var releases: [Release] = []
        var heading: (version: String, date: String?)?
        var lines: [Line] = []
        for raw in markdown.components(separatedBy: .newlines) {
            if raw.hasPrefix("## ") {
                if let heading { releases.append(Release(version: heading.version, date: heading.date, lines: lines)) }
                heading = Self.heading(raw.dropFirst(3))
                lines = []
            } else if heading != nil, let line = Self.line(raw) {
                lines.append(line)
            }
        }
        if let heading { releases.append(Release(version: heading.version, date: heading.date, lines: lines)) }
        self.releases = releases
    }

    private static func heading(_ text: Substring) -> (String, String?) {
        let parts = text.components(separatedBy: " — ")
        let version = parts[0].trimmingCharacters(in: .whitespaces)
        return (version, parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil)
    }

    private static func line(_ raw: String) -> Line? {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if text.hasPrefix("- ") { return .bullet(String(text.dropFirst(2))) }
        return .paragraph(text)
    }
}
