import SwiftUI

/// A heading in the pair grid: Default, Neon, Colors, then the user's own pairs.
struct PairSection: Identifiable {
    let id: String
    let title: String
    let pairs: [PointerPair]

    private static let order: [(id: String, title: String)] = [
        ("default", String(localized: "Default")),
        ("neon", String(localized: "Neon")),
        ("colors", String(localized: "Colors")),
        ("custom", String(localized: "Custom")),
    ]

    /// Groups pairs in display order and drops empty sections. Built-ins without a known group
    /// fall under Colors, so a typo in pairs.json never hides a pair.
    static func sections(for pairs: [PointerPair]) -> [PairSection] {
        let grouped = Dictionary(grouping: pairs, by: key)
        return order.compactMap { entry in
            guard let pairs = grouped[entry.id], !pairs.isEmpty else { return nil }
            return PairSection(id: entry.id, title: entry.title, pairs: pairs)
        }
    }

    private static func key(_ pair: PointerPair) -> String {
        if pair.isCustom { return "custom" }
        let known = order.map(\.id)
        return pair.group.flatMap { known.contains($0) ? $0 : nil } ?? "colors"
    }
}
