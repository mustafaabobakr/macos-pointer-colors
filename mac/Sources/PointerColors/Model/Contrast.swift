import Foundation

extension RGBA {
    /// WCAG 2 relative luminance.
    var relativeLuminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2 contrast ratio, 1...21.
    func contrast(with other: RGBA) -> Double {
        let (a, b) = (relativeLuminance, other.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Whether a pair stands out on light and dark screens. A pointer is easy to spot when either its
/// outline or its fill reaches 3:1 against the background (the WCAG level for graphics).
struct PairVisibility: Equatable {
    static let minimumContrast = 3.0
    static let lightBackground = RGBA(red: 1, green: 1, blue: 1)
    static let darkBackground = RGBA(red: 0.11, green: 0.11, blue: 0.118)

    let hardOnLight: Bool
    let hardOnDark: Bool

    init(_ pair: PointerPair) {
        hardOnLight = !Self.standsOut(pair, on: Self.lightBackground)
        hardOnDark = !Self.standsOut(pair, on: Self.darkBackground)
    }

    /// Nil when the pair is easy to see everywhere.
    var warning: String? {
        switch (hardOnLight, hardOnDark) {
        case (true, true): return String(localized: "Hard to see on light and dark screens")
        case (true, false): return String(localized: "Hard to see on light screens")
        case (false, true): return String(localized: "Hard to see on dark screens")
        case (false, false): return nil
        }
    }

    private static func standsOut(_ pair: PointerPair, on background: RGBA) -> Bool {
        max(pair.outline.contrast(with: background), pair.fill.contrast(with: background)) >= minimumContrast
    }
}
