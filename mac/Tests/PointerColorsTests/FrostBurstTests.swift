import XCTest
@testable import PointerColors

/// The Frost pulse's timeline, measured from the reference clip, and its settings.
@MainActor
final class FrostBurstTests: XCTestCase {
    private let burst = FrostBurst(radius: 100)

    func testRingGrowsFromAQuarterToFullThenIsGone() {
        let radii = (1...6).map { burst.ring(at: Double($0) * FrostBurst.frame).radius }
        XCTAssertEqual(radii.first ?? 0, 24, accuracy: 0.5)
        XCTAssertEqual(radii.last ?? 0, 100, accuracy: 0.5)
        XCTAssertEqual(radii, radii.sorted(), "the ring only grows")
        XCTAssertEqual(burst.ring(at: FrostBurst.ringEnd).opacity, 0)
    }

    func testFlashFillsTheFirstFrameOnly() {
        XCTAssertEqual(burst.flashCore(at: 0).opacity, 1)
        XCTAssertEqual(burst.flashCore(at: 1.5 * FrostBurst.frame).opacity, 0)
        XCTAssertEqual(burst.flashGlow(at: 0).radius, 100 * FrostBurst.flashReach, accuracy: 0.001)
    }

    func testShardsAreTheSameForTheSameSeedAndFadeByTheEnd() {
        let shards = FrostBurst.shards(count: 6, seed: 42)
        XCTAssertEqual(shards, FrostBurst.shards(count: 6, seed: 42))
        XCTAssertNotEqual(shards, FrostBurst.shards(count: 6, seed: 43))
        for shard in shards {
            XCTAssertEqual(burst.place(shard, at: 1).opacity, 0)
            XCTAssertLessThanOrEqual(hypot(burst.place(shard, at: 1).center.x, burst.place(shard, at: 1).center.y), burst.reach)
        }
    }

    func testGlowBandLocationsStayInOrder() {
        for step in 0...14 {
            let locations = burst.glowBand(at: Double(step) / 14).locations
            XCTAssertEqual(locations, locations.sorted())
            XCTAssertTrue(locations.allSatisfy { (0...1).contains($0) })
        }
    }

    func testSettingsStartAsTheClipAndAreRemembered() {
        let defaults = UserDefaults(suiteName: "FrostBurstTests-\(UUID().uuidString)")!
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.frostGrowth, 3)
        XCTAssertEqual(highlight.frostShards, 6)
        XCTAssertTrue(highlight.frostFlash)
        XCTAssertTrue(highlight.frostIce)
        highlight.pulseStyle = .frost
        highlight.frostGrowth = 4.5
        highlight.frostShards = 0
        highlight.frostFlash = false
        highlight.frostIce = false
        let reread = PointerHighlight(defaults: defaults)
        XCTAssertEqual(reread.pulseStyle, .frost)
        XCTAssertEqual([reread.frostGrowth, Double(reread.frostShards)], [4.5, 0])
        XCTAssertFalse(reread.frostFlash || reread.frostIce)
        let style = HighlightStyle(settings: reread, pair: .featured, pointerScale: 1)
        XCTAssertEqual(style.frostColors, .tinted(style.pulseColor), "ice colors off uses the pulse color")
        XCTAssertEqual(style.pulseRadius, style.frost.reach)
    }
}
