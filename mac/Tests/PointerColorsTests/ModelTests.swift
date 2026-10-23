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

final class PairLinkTests: XCTestCase {
    func testParsesWebsiteLink() {
        let link = PairLink(url: URL(string: "pointercolors://add?name=Aqua%20mint&outline=00FFDA&fill=008A59")!)
        XCTAssertEqual(link?.name, "Aqua mint")
        XCTAssertEqual(link?.outline.hex, "00FFDA")
        XCTAssertEqual(link?.fill.hex, "008A59")
    }

    func testRejectsBadColorsAndOtherSchemes() {
        XCTAssertNil(PairLink(url: URL(string: "pointercolors://add?outline=ZZZ&fill=008A59")!))
        XCTAssertNil(PairLink(url: URL(string: "https://add?outline=00FFDA&fill=008A59")!))
        XCTAssertNil(PairLink(url: URL(string: "pointercolors://delete?outline=00FFDA&fill=008A59")!))
    }

    func testCapsLongNamesAndFillsMissingOnes() {
        let long = String(repeating: "a", count: 100)
        XCTAssertEqual(PairLink(url: URL(string: "pointercolors://add?name=\(long)&outline=FFFFFF&fill=000000")!)?.name.count, 40)
        XCTAssertEqual(PairLink(url: URL(string: "pointercolors://add?outline=FFFFFF&fill=000000")!)?.name, "From the website")
    }
}

final class ContrastTests: XCTestCase {
    func testWhiteOnBlackIsMaximum() {
        XCTAssertEqual(RGBA(hex: "FFFFFF")!.contrast(with: RGBA(hex: "000000")!), 21, accuracy: 0.01)
    }

    func testClassicIsVisibleEverywhere() {
        XCTAssertNil(PairVisibility(.classic).warning)
    }

    func testPastelPairIsHardOnLight() {
        let pastel = PointerPair(id: "p", name: "Pastel", outline: RGBA(hex: "FFF5F0")!, fill: RGBA(hex: "FFE3D8")!)
        let visibility = PairVisibility(pastel)
        XCTAssertTrue(visibility.hardOnLight)
        XCTAssertFalse(visibility.hardOnDark)
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

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparisonIsNumeric() {
        XCTAssertTrue(UpdateChecker.isNewer("0.10.0", than: "0.9.3"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0", than: "0.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.1"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.2.0"))
    }

    func testReadsGitHubRelease() {
        let json = #"{"tag_name":"v0.2.0","html_url":"https://github.com/x/y/releases/tag/v0.2.0"}"#.data(using: .utf8)!
        let result = UpdateChecker.result(data: json, status: 200, current: "0.1.0")
        XCTAssertEqual(result, .available(version: "0.2.0", url: URL(string: "https://github.com/x/y/releases/tag/v0.2.0")!))
        XCTAssertEqual(UpdateChecker.result(data: json, status: 200, current: "0.2.0"), .upToDate)
    }

    func testMissingReleasesAndErrors() {
        XCTAssertEqual(UpdateChecker.result(data: Data(), status: 404, current: "0.1.0"), .noReleases)
        XCTAssertEqual(UpdateChecker.result(data: Data(), status: 500, current: "0.1.0"), .failed("GitHub answered 500."))
    }
}
