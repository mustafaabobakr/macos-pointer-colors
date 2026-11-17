import XCTest
@testable import PointerColors

/// The Bokeh pulse's timeline, measured frame by frame from the reference clip.
@MainActor
final class BokehBurstTests: XCTestCase {
    private let burst = BokehBurst(base: 44)

    private func time(_ frame: Double) -> Double { frame / BokehBurst.frames }

    func testMiddleSquareShrinksAsMeasuredOnBothClicks() {
        let measured: [(frame: Double, side: Double)] = [(0, 164), (4, 100), (6, 73.5), (8, 50), (10, 31.5), (12, 16.5)]
        for (frame, side) in measured {
            XCTAssertEqual(burst.middle(at: time(frame)).side, side, accuracy: 0.01, "frame \(frame)")
        }
        XCTAssertEqual(burst.middle(at: time(11)).opacity, 1)
        XCTAssertEqual(burst.middle(at: 1).opacity, 0)
        XCTAssertEqual(BokehBurst.clipLength, 13.0 / 60, accuracy: 0.0001)
    }

    func testSizeScalesTheWholeBurst() {
        XCTAssertEqual(BokehBurst(base: 88).middle(at: 0).side, 328, accuracy: 0.01)
        XCTAssertEqual(BokehBurst(base: 88).reach, burst.reach * 2, accuracy: 0.01)
    }

    func testSquaresSitEvenlyAroundTheClickAsInTheClip() {
        XCTAssertEqual([0, 0.74, 0.75, 0.85, 0.86, 0.92, 0.93, 0.99].map(BokehBurst.layoutCount), [5, 5, 4, 4, 3, 3, 2, 2])
        let counts = Set((0..<300).map { BokehBurst.tiles(seed: UInt64($0)).count })
        XCTAssertEqual(counts, [2, 3, 4, 5])
        XCTAssertEqual(BokehBurst.tiles(seed: 42), BokehBurst.tiles(seed: 42))
        for seed in 0..<50 {
            let tiles = BokehBurst.tiles(seed: UInt64(seed))
            XCTAssertEqual(tiles.first?.angle ?? -1, 0, accuracy: 0.0001, "the first goes straight right")
            for (index, tile) in tiles.enumerated() {
                XCTAssertEqual(tile.angle, 2 * .pi * Double(index) / Double(tiles.count), accuracy: 0.0001)
                XCTAssertTrue((0...1).contains(tile.shade))
            }
        }
    }

    func testColorsRunFromOrangeToPaleGoldAtFullBrightness() {
        let orange = BokehColors.square(hue: 18)
        XCTAssertEqual(orange.red, 1, accuracy: 0.0001)
        XCTAssertEqual(orange.green, 0.419, accuracy: 0.0001)
        XCTAssertEqual(orange.blue, 0.17, accuracy: 0.0001)
        let pale = BokehColors.square(hue: 38)
        XCTAssertEqual(pale.red, 1)
        XCTAssertEqual(pale.blue, 0.55, accuracy: 0.0001)
    }

    func testSquaresKeepMovingAtTheirOwnSpeedWhileTheyFade() throws {
        let tile = try XCTUnwrap(BokehBurst.tiles(seed: 3).first)
        let distance = { (frame: Double) -> Double in
            let center = self.burst.place(tile, at: self.time(frame)).center
            return hypot(center.x, center.y)
        }
        XCTAssertEqual(distance(9) - distance(8), tile.speed, accuracy: 0.01, "steady speed after the first frames")
        XCTAssertGreaterThan(distance(3) - distance(2), tile.speed, "faster as they leave")
        XCTAssertEqual(burst.place(tile, at: time(0)).square.opacity, 0)
        XCTAssertEqual(burst.place(tile, at: 1).square.opacity, 0)
        for tile in BokehBurst.tiles(seed: 5) {
            let end = burst.place(tile, at: 1)
            XCTAssertLessThanOrEqual(hypot(end.center.x, end.center.y) + end.square.side / 2, burst.reach)
        }
    }

    func testBokehPlaysAtTheClipSpeedWhileOtherStylesKeepLength() {
        let defaults = UserDefaults(suiteName: "BokehBurstTests-\(UUID().uuidString)")!
        let highlight = PointerHighlight(defaults: defaults)
        highlight.pulseDuration = 1.2
        highlight.pulseStyle = .bokeh
        var style = HighlightStyle(settings: highlight, pair: .featured, pointerScale: 1)
        XCTAssertEqual(style.pulseDuration, BokehBurst.clipLength / PointerHighlight.defaultBokehSpeed, accuracy: 0.0001)
        XCTAssertEqual(style.pulseRadius, style.bokeh.reach)
        style.pulseStyle = .ring
        XCTAssertEqual(style.pulseDuration, 1.2)
        XCTAssertEqual(PointerHighlight(defaults: defaults).pulseStyle, .bokeh)
    }

    func testSpeedScalesHowLongBokehPlaysAndIsRemembered() {
        let defaults = UserDefaults(suiteName: "BokehSpeedTests-\(UUID().uuidString)")!
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.bokehSpeed, 0.55, "a little over half the clip's speed by default")
        highlight.pulseStyle = .bokeh
        highlight.bokehSpeed = 1
        let style = HighlightStyle(settings: highlight, pair: .featured, pointerScale: 1)
        XCTAssertEqual(style.pulseDuration, BokehBurst.clipLength, accuracy: 0.0001, "1× is the clip's own speed")
        highlight.bokehSpeed = 0.25
        XCTAssertEqual(HighlightStyle(settings: highlight, pair: .featured, pointerScale: 1).pulseDuration,
                       BokehBurst.clipLength * 4, accuracy: 0.0001)
        XCTAssertEqual(PointerHighlight(defaults: defaults).bokehSpeed, 0.25)
        defaults.set(2.0, forKey: "highlightBokehSpeed")
        XCTAssertEqual(PointerHighlight(defaults: defaults).bokehSpeed, 1, "a speed saved before the top was 1× is brought down to it")
    }

    func testBlurZeroDrawsSharpShapesWithNoGlow() throws {
        let sharp = BokehBurst(base: 44, softness: 0)
        let tile = try XCTUnwrap(BokehBurst.tiles(seed: 8).first)
        for frame in stride(from: 0.0, through: 13, by: 1) {
            XCTAssertEqual(sharp.middle(at: time(frame)).blur, 0)
            XCTAssertEqual(sharp.middleGlow(at: time(frame)), 0)
            XCTAssertEqual(sharp.place(tile, at: time(frame)).square.blur, 0)
        }
        XCTAssertEqual(sharp.haloStrength, 0, "no glow around the lines")
        let soft = BokehBurst(base: 44, softness: 2)
        XCTAssertEqual(soft.middleGlow(at: 0), burst.middleGlow(at: 0) * 2, accuracy: 0.0001)
        XCTAssertEqual(soft.haloStrength, 1)
        XCTAssertGreaterThanOrEqual(soft.reach, burst.reach)
    }

    func testBlurSettingIsRememberedAndBackedUp() throws {
        let suite = "BokehBlur-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.bokehBlur, 1, "the clip's blur by default")
        highlight.bokehBlur = 0
        XCTAssertEqual(HighlightStyle(settings: highlight, pair: .featured, pointerScale: 1).bokeh.softness, 0)
        let backup = SettingsBackup(defaults: defaults, domain: suite)
        let data = try backup.export(launchAtLogin: false)
        highlight.bokehBlur = 1.5
        try backup.restore(from: data)
        XCTAssertEqual(PointerHighlight(defaults: defaults).bokehBlur, 0)
    }

    func testCustomShapesUseOnlyTheCheckedOnesEachAsLikely() {
        for shape in BokehShape.allCases {
            let counts = Set((0..<40).map { BokehBurst.tiles(seed: UInt64($0), shapes: [shape]).count })
            XCTAssertEqual(counts, [shape.count])
        }
        let picked: [BokehShape] = [.cross, .pair]
        let counts = (0..<400).map { BokehBurst.tiles(seed: UInt64($0), shapes: picked).count }
        XCTAssertEqual(Set(counts), [4, 2])
        XCTAssertEqual(Double(counts.filter { $0 == 4 }.count) / 400, 0.5, accuracy: 0.1)
        XCTAssertEqual(BokehBurst.pick(from: [], roll: 0.5), nil)
    }

    func testShapeSettingsKeepOneShapeAndAreRemembered() throws {
        let suite = "BokehShapes-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.bokehShapeChoice, .all)
        XCTAssertNil(highlight.bokehShapes, "All uses the clip's rates")
        XCTAssertEqual(highlight.bokehCustomShapes, BokehShape.allCases)
        highlight.bokehShapeChoice = .custom
        [BokehShape.pentagon, .triangle, .pair].forEach(highlight.toggleBokehShape)
        XCTAssertEqual(highlight.bokehCustomShapes, [.cross])
        highlight.toggleBokehShape(.cross)
        XCTAssertEqual(highlight.bokehCustomShapes, [.cross], "the last shape stays checked")
        XCTAssertEqual(HighlightStyle(settings: highlight, pair: .featured, pointerScale: 1).bokehShapes, [.cross])
        let backup = SettingsBackup(defaults: defaults, domain: suite)
        let data = try backup.export(launchAtLogin: false)
        highlight.bokehShapeChoice = .all
        highlight.toggleBokehShape(.pentagon)
        try backup.restore(from: data)
        let restored = PointerHighlight(defaults: defaults)
        XCTAssertEqual(restored.bokehShapeChoice, .custom)
        XCTAssertEqual(restored.bokehCustomShapes, [.cross])
    }

    func testEveryColorComesFromThePaletteAtItsBrightest() {
        let clip = BokehPalette.clip
        for (shade, hue) in [(0.0, 18.0), (0.5, 28.0), (1.0, 38.0)] {
            let expected = BokehColors.square(hue: hue)
            let got = clip.square(shade: shade)
            XCTAssertEqual(got.red, expected.red, accuracy: 0.001)
            XCTAssertEqual(got.green, expected.green, accuracy: 0.001)
            XCTAssertEqual(got.blue, expected.blue, accuracy: 0.001)
        }
        XCTAssertEqual(clip.middle, BokehColors.middle)
        let dark = BokehPalette.tint(RGBA(red: 0, green: 0.25, blue: 0.5))
        XCTAssertEqual(dark.deep.value, 1, "a dark color is brought to its brightest")
        XCTAssertLessThan(dark.pale.saturation, dark.deep.saturation, "the pale end is paler")
    }

    func testHarmonyLooksKeepTheClipsLightnessAndColorfulness() {
        let emerald = PointerPair.builtIns.first { $0.id == "glow-emerald" }!.highlightColor
        let hue = OKLCH(emerald).hue
        for look in [BokehColorLook.analogous, .monochrome] {
            let palette = look.palette(for: emerald)
            let deep = OKLCH(palette.square(shade: 0))
            let pale = OKLCH(palette.square(shade: 1))
            XCTAssertEqual(deep.lightness, BokehPalette.clipDeep.lightness, accuracy: 0.01, "\(look)")
            XCTAssertEqual(pale.lightness, BokehPalette.clipPale.lightness, accuracy: 0.01, "\(look)")
            XCTAssertLessThanOrEqual(deep.chroma, BokehPalette.clipDeep.chroma + 0.005)
            XCTAssertEqual(deep.hue, hue, accuracy: 2, "\(look) starts in the pair's hue")
        }
        let turn = OKLCH(BokehColorLook.analogous.palette(for: emerald).square(shade: 1)).hue - hue
        XCTAssertEqual(turn, 40, accuracy: 3, "Analogous turns 40° as it pales")
        XCTAssertEqual(OKLCH(BokehColorLook.monochrome.palette(for: emerald).square(shade: 1)).hue, hue, accuracy: 3)
        let tint = BokehColorLook.tint.palette(for: emerald)
        XCTAssertEqual(HSV(tint.square(shade: 0)).value, 1, accuracy: 0.001, "Tint stays at full brightness")
    }

    func testOKLCHRoundTripsScreenColors() {
        for hex in ["FF6B2B", "FFD58C", "00FF40", "4D7CFF"] {
            let color = RGBA(hex: hex)!
            let back = OKLCH(color).rgba
            XCTAssertEqual(back.red, color.red, accuracy: 0.002)
            XCTAssertEqual(back.green, color.green, accuracy: 0.002)
            XCTAssertEqual(back.blue, color.blue, accuracy: 0.002)
        }
    }

    func testColorSourceDefaultsToTheClipAndIsRemembered() throws {
        let suite = "BokehColor-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.bokehColorSource, .clip)
        XCTAssertEqual(highlight.bokehPalette(for: .featured), .clip)
        highlight.bokehColorSource = .custom
        highlight.bokehColor = RGBA(hex: "3A7BFF")!
        XCTAssertEqual(HighlightStyle(settings: highlight, pair: .featured, pointerScale: 1).bokehPalette,
                       .tint(RGBA(hex: "3A7BFF")!), "Tint is the look to start with")
        let backup = SettingsBackup(defaults: defaults, domain: suite)
        let data = try backup.export(launchAtLogin: false)
        highlight.bokehColorSource = .pair
        try backup.restore(from: data)
        let restored = PointerHighlight(defaults: defaults)
        XCTAssertEqual(restored.bokehColorSource, .custom)
        XCTAssertEqual(restored.bokehColor, RGBA(hex: "3A7BFF")!)
        restored.bokehColorSource = .pair
        XCTAssertEqual(restored.bokehPalette(for: .featured), .tint(PointerPair.featured.highlightColor))
        restored.bokehColorLook = .monochrome
        XCTAssertEqual(restored.bokehPalette(for: .featured), .monochrome(PointerPair.featured.highlightColor))
        XCTAssertEqual(PointerHighlight(defaults: defaults).bokehColorLook, .monochrome, "the look is remembered")
    }

    func testBackupCarriesBokehSpeed() throws {
        let suite = "BokehSpeedBackup-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let highlight = PointerHighlight(defaults: defaults)
        highlight.bokehSpeed = 0.8
        let backup = SettingsBackup(defaults: defaults, domain: suite)
        let data = try backup.export(launchAtLogin: false)
        highlight.bokehSpeed = 0.5
        try backup.restore(from: data)
        XCTAssertEqual(PointerHighlight(defaults: defaults).bokehSpeed, 0.8)
    }
}
