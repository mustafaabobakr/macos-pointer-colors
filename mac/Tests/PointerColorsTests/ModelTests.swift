import XCTest
@testable import PointerColors

final class RGBATests: XCTestCase {
    func testHexRoundTrip() {
        XCTAssertEqual(RGBA(hex: "#00FFDA")?.hex, "00FFDA")
        XCTAssertEqual(RGBA(hex: "008a59")?.hex, "008A59")
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(RGBA(hex: "FFF"))
        XCTAssertNil(RGBA(hex: "GGGGGG"))
    }

    func testPreferenceDictionaryRoundTrip() {
        let color = RGBA(hex: "0A84FF")!
        XCTAssertEqual(RGBA(preferenceValue: color.preferenceValue)?.hex, "0A84FF")
    }

    /// macOS stores 0.854902 for DA; the pair must still be recognised as applied.
    func testMatchesRoundedPreferenceValues() {
        let stored = RGBA(red: 0, green: 1, blue: 0.854902)
        let fill = RGBA(red: 0, green: 0.5411764705882353, blue: 0.349019)
        XCTAssertTrue(PointerPair.builtIns[0].matches(outline: stored, fill: fill))
    }
}

final class TextSizeTests: XCTestCase {
    func testAutomaticIsLargeOnlyOnWideScreens() {
        XCTAssertEqual(TextSize.automatic.factor(screenWidth: 1512), 1)
        XCTAssertEqual(TextSize.automatic.factor(screenWidth: 2560), TextSize.large.factor(screenWidth: 0))
    }

    func testFixedSizesIgnoreScreen() {
        XCTAssertEqual(TextSize.huge.factor(screenWidth: 800), 1.5)
        XCTAssertEqual(TextSize.standard.factor(screenWidth: 5000), 1)
    }
}

final class PairLibraryTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "PairLibraryTests-\(UUID().uuidString)")
    }

    func testCustomPairsPersist() {
        var library = PairLibrary(defaults: defaults)
        library.add(.custom(name: "Mine", outline: RGBA(hex: "FFFFFF")!, fill: RGBA(hex: "FF6FA8")!))
        XCTAssertEqual(PairLibrary(defaults: defaults).custom.map(\.name), ["Mine"])
    }

    func testHiddenPairsLeaveVisibleList() {
        var library = PairLibrary(defaults: defaults)
        library.setHidden(true, id: "glacier")
        XCTAssertFalse(library.visible.contains { $0.id == "glacier" })
        XCTAssertEqual(library.all.count, PointerPair.builtIns.count)
    }

    func testRemoveCustomAlsoClearsHidden() {
        var library = PairLibrary(defaults: defaults)
        let pair = PointerPair.custom(name: "Temp", outline: RGBA(hex: "000000")!, fill: RGBA(hex: "FFFFFF")!)
        library.add(pair)
        library.setHidden(true, id: pair.id)
        library.remove(id: pair.id)
        XCTAssertTrue(library.custom.isEmpty)
        XCTAssertFalse(library.hiddenIDs.contains(pair.id))
    }

    func testExportImportRoundTrip() throws {
        var source = PairLibrary(defaults: defaults)
        source.add(.custom(name: "Exported", outline: RGBA(hex: "112233")!, fill: RGBA(hex: "445566")!))
        var target = PairLibrary(defaults: UserDefaults(suiteName: "target-\(UUID().uuidString)")!)
        try target.importCustom(from: source.exportCustom())
        XCTAssertEqual(target.custom.map(\.fill.hex), ["445566"])
    }
}
