import Foundation

/// An outline/fill color pair for the macOS pointer.
struct PointerPair: Codable, Hashable, Identifiable {
    /// Marks the two pairs that match macOS's own defaults.
    enum SystemDefault: String, Codable {
        case light, dark
    }

    var id: String
    var name: String
    var outline: RGBA
    var fill: RGBA
    var isCustom: Bool = false
    var system: SystemDefault?
    /// Heading in pairs.json: "default", "neon" or "colors". Nil for custom pairs.
    var group: String?

    static func custom(name: String, outline: RGBA, fill: RGBA) -> PointerPair {
        PointerPair(id: "custom-\(UUID().uuidString)", name: name, outline: outline, fill: fill, isCustom: true)
    }

    /// True when both colors match, ignoring tiny rounding from the preferences file.
    func matches(outline other: RGBA, fill otherFill: RGBA) -> Bool {
        outline.hex == other.hex && fill.hex == otherFill.hex
    }
}

extension PointerPair {
    /// Built-in pairs from pairs.json (shared with the website), macOS defaults first.
    static let builtIns: [PointerPair] = PairCatalog.load()

    static var macOSLight: PointerPair { systemDefault(.light) }
    static var macOSDark: PointerPair { systemDefault(.dark) }

    /// The first non-default pair: what the app shows before anything is chosen.
    static var featured: PointerPair { builtIns.first { $0.system == nil } ?? builtIns[0] }

    static func systemDefault(dark: Bool) -> PointerPair {
        dark ? macOSDark : macOSLight
    }

    private static func systemDefault(_ kind: SystemDefault) -> PointerPair {
        builtIns.first { $0.system == kind } ?? builtIns[0]
    }
}
