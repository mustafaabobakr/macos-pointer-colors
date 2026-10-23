import Foundation

/// Loads the built-in pairs from `pairs.json`, the list the website uses too.
/// The build script copies it into the app's Resources; `swift run` and tests read it
/// from the repo root instead.
enum PairCatalog {
    static let fileName = "pairs.json"

    static func load() -> [PointerPair] {
        for url in candidateURLs() {
            if let pairs = try? decode(Data(contentsOf: url)), !pairs.isEmpty { return pairs }
        }
        return fallback
    }

    static func decode(_ data: Data) throws -> [PointerPair] {
        try JSONDecoder().decode(File.self, from: data).pairs.compactMap(\.pair)
    }

    /// The repo copy, found relative to this source file. Only exists on a development machine.
    static var repoURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Model
            .deletingLastPathComponent() // PointerColors
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // mac
            .deletingLastPathComponent() // repo root
            .appendingPathComponent(fileName)
    }

    private static func candidateURLs() -> [URL] {
        let bundled = Bundle.main.url(forResource: "pairs", withExtension: "json")
        return [bundled, repoURL].compactMap { $0 }
    }

    /// Only used if pairs.json is missing: the two macOS defaults, so the app still works.
    private static let fallback: [PointerPair] = [
        PointerPair(id: "macos-light", name: "macOS light", outline: RGBA(hex: "FFFFFF")!, fill: RGBA(hex: "000000")!, system: .light),
        PointerPair(id: "macos-dark", name: "macOS dark", outline: RGBA(hex: "000000")!, fill: RGBA(hex: "FFFFFF")!, system: .dark),
    ]

    private struct File: Decodable {
        let pairs: [Entry]
    }

    private struct Entry: Decodable {
        let id: String
        let name: String
        let outline: String
        let fill: String
        let system: PointerPair.SystemDefault?

        var pair: PointerPair? {
            guard let o = RGBA(hex: outline), let f = RGBA(hex: fill) else { return nil }
            return PointerPair(id: id, name: name, outline: o, fill: f, system: system)
        }
    }
}
