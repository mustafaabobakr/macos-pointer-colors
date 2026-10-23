import XCTest
@testable import PointerColors

/// Checks the shared pairs.json the website and the app both read.
final class PairCatalogTests: XCTestCase {
    private func pairs() throws -> [PointerPair] {
        try PairCatalog.decode(Data(contentsOf: PairCatalog.repoURL))
    }

    func testMacOSDefaultsComeFirst() throws {
        let pairs = try pairs()
        XCTAssertEqual(pairs.prefix(2).map(\.system), [.light, .dark])
        XCTAssertEqual(pairs[0].outline.hex + pairs[0].fill.hex, "FFFFFF000000")
        XCTAssertEqual(pairs[1].outline.hex + pairs[1].fill.hex, "000000FFFFFF")
    }

    func testIDsAndColorsAreUnique() throws {
        let pairs = try pairs()
        XCTAssertEqual(Set(pairs.map(\.id)).count, pairs.count)
        XCTAssertEqual(Set(pairs.map { $0.outline.hex + $0.fill.hex }).count, pairs.count)
    }

    func testEveryColorParsed() throws {
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: PairCatalog.repoURL)) as? [String: Any]
        let count = (raw?["pairs"] as? [Any])?.count
        XCTAssertEqual(try pairs().count, count, "an entry with a bad hex code was dropped")
    }

    /// Sakura is kept as it always was; anything new must be easy to see everywhere.
    func testNewPairsAreVisibleOnLightAndDark() throws {
        let hard = try pairs().filter { PairVisibility($0).warning != nil }.map(\.id)
        XCTAssertEqual(hard, ["sakura"])
    }
}
