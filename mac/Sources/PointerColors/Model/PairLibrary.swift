import Foundation

/// Built-in pairs plus the user's custom ones, with which pairs are hidden from the menu.
/// Persists custom pairs and hidden ids in the app's own UserDefaults.
struct PairLibrary {
    private(set) var custom: [PointerPair]
    private(set) var hiddenIDs: Set<String>

    private let defaults: UserDefaults
    private static let customKey = "customPairs"
    private static let hiddenKey = "hiddenPairIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        custom = Self.decode([PointerPair].self, defaults.data(forKey: Self.customKey)) ?? []
        hiddenIDs = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
    }

    var all: [PointerPair] { PointerPair.builtIns + custom }
    var visible: [PointerPair] { all.filter { !hiddenIDs.contains($0.id) } }

    func pair(id: String?) -> PointerPair? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    /// The first pair whose colors match, so the menu can show what's applied right now.
    func pair(matching outline: RGBA, fill: RGBA) -> PointerPair? {
        all.first { $0.matches(outline: outline, fill: fill) }
    }

    mutating func add(_ pair: PointerPair) {
        custom.append(pair)
        save()
    }

    mutating func update(_ pair: PointerPair) {
        guard let index = custom.firstIndex(where: { $0.id == pair.id }) else { return }
        custom[index] = pair
        save()
    }

    mutating func remove(id: String) {
        custom.removeAll { $0.id == id }
        hiddenIDs.remove(id)
        save()
    }

    mutating func setHidden(_ hidden: Bool, id: String) {
        if hidden { hiddenIDs.insert(id) } else { hiddenIDs.remove(id) }
        save()
    }

    /// Replaces custom pairs with the ones in an exported file; built-ins are never touched.
    mutating func importCustom(from data: Data) throws {
        let pairs = try JSONDecoder().decode([PointerPair].self, from: data)
        custom = pairs.map { PointerPair.custom(name: $0.name, outline: $0.outline, fill: $0.fill) }
        save()
    }

    func exportCustom() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(custom)
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(custom), forKey: Self.customKey)
        defaults.set(Array(hiddenIDs).sorted(), forKey: Self.hiddenKey)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
