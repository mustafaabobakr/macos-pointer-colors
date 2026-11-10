import XCTest
@testable import PointerColors

/// The ring, pulse, long-press and laser looks that became settings: they start at what was drawn
/// before, are saved, and reach what the overlay draws.
@MainActor
final class HighlightLookTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "HighlightLookTests-\(UUID().uuidString)")!
    }

    func testStartAtTheValuesDrawnBefore() {
        let style = HighlightStyle(settings: PointerHighlight(defaults: makeDefaults()), pair: .featured, pointerScale: 1)
        XCTAssertEqual(style, Self.styleWithSettingsOf(style), "a new install draws as the plain style does")
        XCTAssertEqual([style.ringFill, style.ringLineWidth, style.ringOpacity], [0.18, 3, 0.9])
        XCTAssertEqual([style.pulseLineWidth, style.pulseGrowth, style.pulseOpacity], [4, 1.8, 0.95])
        XCTAssertEqual(style.rippleWaves, 3)
        XCTAssertEqual([style.rippleGrowth, style.rippleSpacing, style.rippleLineWidth, style.rippleOpacity], [2.2, 0.15, 3, 0.9])
        XCTAssertEqual([style.holdDelay, style.holdSize, style.holdFill, style.holdLineWidth], [0.35, 0.55, 0.35, 3])
        XCTAssertTrue(style.holdBreathes)
        XCTAssertEqual([style.dotFade, style.classicTrailOpacity, style.laserGlow], [0.42, 0.95, 0.2])
        XCTAssertEqual([style.goodNotesFadeOut, style.goodNotesRim], [0.35, 2.4])
    }

    /// The plain style, with the colors and sizes that come from the pair and the switches.
    private static func styleWithSettingsOf(_ style: HighlightStyle) -> HighlightStyle {
        var plain = HighlightStyle()
        (plain.showsRing, plain.ringColor, plain.pulseColor, plain.pulseOutline) = (style.showsRing, style.ringColor, style.pulseColor, style.pulseOutline)
        (plain.laser, plain.showsHold, plain.laserOutlined) = (style.laser, style.showsHold, style.laserOutlined)
        return plain
    }

    func testSavedAndReadBack() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        highlight.ringLineWidth = 6
        highlight.pulseGrowth = 2.5
        highlight.rippleWaves = 5
        highlight.holdBreathes = false
        highlight.laserDotFade = 2
        highlight.laserRim = 4
        let reopened = PointerHighlight(defaults: defaults)
        XCTAssertEqual(reopened.ringLineWidth, 6)
        XCTAssertEqual(reopened.pulseGrowth, 2.5)
        XCTAssertEqual(reopened.rippleWaves, 5)
        XCTAssertFalse(reopened.holdBreathes)
        XCTAssertEqual(reopened.laserDotFade, 2)
        XCTAssertEqual(reopened.laserRim, 4)
    }

    func testRingColorFollowsThePairUnlessCustom() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        let pair = PointerPair.featured
        XCTAssertEqual(highlight.ringColor(for: pair), pair.highlightColor)
        XCTAssertEqual(HighlightStyle(settings: highlight, pair: pair, pointerScale: 1).ringColor, pair.highlightColor)
        highlight.ringUsesPairColor = false
        highlight.ringColor = RGBA(red: 1, green: 0.3, blue: 0.6)
        XCTAssertEqual(HighlightStyle(settings: highlight, pair: pair, pointerScale: 1).ringColor, highlight.ringColor)
    }

    func testRippleWavesAllEndWithThePulse() {
        var style = HighlightStyle()
        style.pulseDuration = 1
        XCTAssertEqual(style.rippleWaveLength, 0.7, accuracy: 1e-9, "three waves 15% apart, as before")
        let (waves, spacing) = (PointerHighlight.rippleWavesRange.upperBound, PointerHighlight.rippleSpacingRange.upperBound)
        style.rippleWaves = waves
        style.rippleSpacing = spacing
        let lastEnds = style.rippleDelay(waves - 1) + style.rippleWaveLength
        XCTAssertEqual(lastEnds, 1, accuracy: 1e-9, "the most and widest-spaced waves still end with the pulse")
        XCTAssertGreaterThan(style.rippleWaveLength, 0.19)
    }

    func testClassicGlowAndMiddleFollowTheirSettings() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.laserGlow = 0.5
        highlight.laserCoreLightness = 0
        let pair = PointerPair.featured
        let style = HighlightStyle(settings: highlight, pair: pair, pointerScale: 1)
        XCTAssertEqual(style.laserTrailParts.first?.opacity ?? 0, 0.5, accuracy: 1e-9)
        XCTAssertEqual(style.laserDotParts.first?.opacity ?? 0, 0.45, accuracy: 1e-9, "the dot glows 90% as much")
        XCTAssertEqual(style.laser.middle, style.laser.glow, "no lightening keeps the laser color")
    }

    func testGoodNotesHoldsTheTrailThenFadesOverItsFadeOut() {
        var style = HighlightStyle()
        (style.laserLook, style.trailFade, style.goodNotesFadeOut) = (.goodNotes, 2, 0.5)
        XCTAssertEqual(style.trailHold, 1.5, accuracy: 1e-9)
        XCTAssertEqual(style.trailOpacity(after: 1.4), 1, accuracy: 1e-9)
        XCTAssertEqual(style.trailOpacity(after: 2), 0, accuracy: 1e-9)
    }
}
