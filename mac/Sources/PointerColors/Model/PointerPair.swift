import Foundation

/// An outline/fill color pair for the macOS pointer.
struct PointerPair: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var outline: RGBA
    var fill: RGBA
    var isCustom: Bool = false

    static func custom(name: String, outline: RGBA, fill: RGBA) -> PointerPair {
        PointerPair(id: "custom-\(UUID().uuidString)", name: name, outline: outline, fill: fill, isCustom: true)
    }

    /// True when both colors match, ignoring tiny rounding from the preferences file.
    func matches(outline other: RGBA, fill otherFill: RGBA) -> Bool {
        outline.hex == other.hex && fill.hex == otherFill.hex
    }
}

extension PointerPair {
    static let classic = builtIn("classic", "Classic", "FFFFFF", "000000")

    /// The same pairs as the website, in the same order.
    static let builtIns: [PointerPair] = [
        builtIn("aqua-mint", "Aqua mint", "00FFDA", "008A59"),
        builtIn("aqua-green", "Aqua green", "00FFDA", "008A00"),
        builtIn("glacier", "Glacier", "FFFFFF", "0A84FF"),
        builtIn("ultraviolet", "Ultraviolet", "FF4FD8", "5B21B6"),
        builtIn("solar-flare", "Solar flare", "FFD60A", "E85D04"),
        builtIn("coral-reef", "Coral reef", "FFE3D8", "FF453A"),
        builtIn("sakura", "Sakura", "FFFFFF", "FF6FA8"),
        builtIn("lavender", "Lavender", "E9D5FF", "7C3AED"),
        builtIn("lime-ink", "Lime ink", "D9FF3F", "1C1C1E"),
        builtIn("ember", "Ember", "FF9F0A", "000000"),
        builtIn("deep-sea", "Deep sea", "64D2FF", "004E64"),
        classic,
    ]

    private static func builtIn(_ id: String, _ name: String, _ outline: String, _ fill: String) -> PointerPair {
        PointerPair(id: id, name: name, outline: RGBA(hex: outline)!, fill: RGBA(hex: fill)!)
    }
}
