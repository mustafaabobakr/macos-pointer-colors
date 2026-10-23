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

final class PairSectionTests: XCTestCase {
    func testSectionsComeInOrderWithDefaultsAndNeonTogether() throws {
        let pairs = try PairCatalog.decode(Data(contentsOf: PairCatalog.repoURL))
        let custom = PointerPair.custom(name: "Mine", outline: RGBA(hex: "FFFFFF")!, fill: RGBA(hex: "123456")!)
        let sections = PairSection.sections(for: pairs + [custom])
        XCTAssertEqual(sections.map(\.id), ["default", "neon", "colors", "custom"])
        XCTAssertEqual(sections[0].pairs.map(\.id), ["macos-light", "macos-dark"])
        XCTAssertTrue(sections[1].pairs.contains { $0.id == "aqua-mint" })
        XCTAssertEqual(sections[3].pairs.map(\.name), ["Mine"])
    }

    func testPairsAreGroupedContiguouslyInTheFile() throws {
        let groups = try PairCatalog.decode(Data(contentsOf: PairCatalog.repoURL)).map { $0.group ?? "" }
        let runs = groups.enumerated().filter { $0.offset == 0 || groups[$0.offset - 1] != $0.element }.map(\.element)
        XCTAssertEqual(runs, ["default", "neon", "colors"], "the website shows pairs in file order")
    }
}
