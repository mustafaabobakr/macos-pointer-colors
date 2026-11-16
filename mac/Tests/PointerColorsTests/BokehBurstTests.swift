import XCTest
@testable import PointerColors

/// The Bokeh pulse's timeline, measured from the reference clip, and its settings.
@MainActor
final class BokehBurstTests: XCTestCase {
    private let burst = BokehBurst(base: 44, focus: true)

    func testGlowFrameShowsAtFullSizeThenShrinksAndIsGoneByFrameFour() {
        XCTAssertEqual(burst.glowFrame(at: 0).side, 44 * BokehBurst.frameSide, accuracy: 0.001)
        XCTAssertEqual(burst.glowFrame(at: 0).opacity, 1)
        XCTAssertEqual(burst.glowFrame(at: 3 * BokehBurst.tick).side, 44 * BokehBurst.frameSide * 0.8, accuracy: 0.001)
        XCTAssertEqual(burst.glowFrame(at: 4 * BokehBurst.tick).opacity, 0)
    }

    func testSquaresComeIntoFocusFlyOutAndFade() throws {
        let tiles = BokehBurst.tiles(count: 6, seed: 42)
        XCTAssertEqual(tiles, BokehBurst.tiles(count: 6, seed: 42))
        XCTAssertNotEqual(tiles, BokehBurst.tiles(count: 6, seed: 43))
        let tile = try XCTUnwrap(tiles.first)
        let early = burst.place(tile, at: tile.leaves)
        let landed = burst.place(tile, at: BokehBurst.landsAt)
        XCTAssertEqual(early.square.blur, burst.maxBlur, accuracy: 0.001)
        XCTAssertEqual(burst.place(tile, at: BokehBurst.sharpAt).square.blur, 0)
        XCTAssertGreaterThan(hypot(landed.center.x, landed.center.y), hypot(early.center.x, early.center.y))
        for tile in tiles {
            let end = burst.place(tile, at: 1)
            XCTAssertEqual(end.square.opacity, 0)
            XCTAssertLessThanOrEqual(hypot(end.center.x, end.center.y) + end.square.side / 2, burst.reach)
        }
    }

    func testFocusOffKeepsSquaresSharp() {
        let sharp = BokehBurst(base: 44, focus: false)
        XCTAssertEqual(sharp.middle(at: BokehBurst.tick).blur, 0)
    }

    func testMiddleSquareShrinksAndEndsWithThePulse() {
        XCTAssertGreaterThan(burst.middle(at: 2 * BokehBurst.tick).side, burst.middle(at: 12 * BokehBurst.tick).side)
        XCTAssertEqual(burst.middle(at: 1).opacity, 0)
    }

    func testSettingsStartAsTheClipAndAreRemembered() {
        let defaults = UserDefaults(suiteName: "BokehBurstTests-\(UUID().uuidString)")!
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.bokehTiles, 6)
        XCTAssertTrue(highlight.bokehFrame)
        XCTAssertTrue(highlight.bokehFocus)
        XCTAssertEqual(highlight.bokehColorSource, .gold)
        highlight.pulseStyle = .bokeh
        highlight.bokehTiles = 0
        highlight.bokehFrame = false
        highlight.bokehFocus = false
        highlight.bokehColorSource = .custom
        highlight.bokehColor = RGBA(hex: "FF3B30")!
        let reread = PointerHighlight(defaults: defaults)
        XCTAssertEqual(reread.pulseStyle, .bokeh)
        XCTAssertEqual(reread.bokehTiles, 0)
        XCTAssertFalse(reread.bokehFrame)
        XCTAssertFalse(reread.bokehFocus)
        XCTAssertEqual(reread.bokehColorSource, .custom)
        let style = HighlightStyle(settings: reread, pair: .featured, pointerScale: 1)
        XCTAssertEqual(style.bokehColors, .tinted(RGBA(hex: "FF3B30")!))
        XCTAssertFalse(style.bokeh.focus)
        XCTAssertEqual(style.pulseRadius, style.bokeh.reach)
        reread.bokehColorSource = .pair
        XCTAssertEqual(reread.bokehColors(for: .featured), .tinted(PointerPair.featured.highlightColor))
    }

    func testBackupCarriesTheBokehSettings() throws {
        let suite = "BokehBackupTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let highlight = PointerHighlight(defaults: defaults)
        highlight.bokehTiles = 9
        highlight.bokehColorSource = .pair
        let backup = SettingsBackup(defaults: defaults, domain: suite)
        let data = try backup.export(launchAtLogin: false)
        highlight.bokehTiles = 2
        highlight.bokehColorSource = .gold
        try backup.restore(from: data)
        let restored = PointerHighlight(defaults: defaults)
        XCTAssertEqual(restored.bokehTiles, 9)
        XCTAssertEqual(restored.bokehColorSource, .pair)
    }
}
