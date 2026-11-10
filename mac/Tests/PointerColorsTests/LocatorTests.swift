import XCTest
@testable import PointerColors

/// The pointer locator's ring settings: their defaults, snapping, saving, and the ring they draw.
@MainActor
final class LocatorSettingsTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "LocatorSettingsTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    private func makeLocator(_ defaults: UserDefaults) -> PointerLocator {
        PointerLocator(defaults: defaults, pair: { .featured }, pointerScale: { 1 })
    }

    func testDefaultsMatchTheOldFixedRing() {
        let locator = makeLocator(makeDefaults().0)
        XCTAssertEqual(locator.duration, 0.8)
        XCTAssertEqual(locator.startRadius, 90)
        XCTAssertEqual(locator.endSize, 1)
        XCTAssertEqual(locator.lineWidth, 1)
        XCTAssertEqual(locator.pressGap, 1)
        let look = locator.look
        XCTAssertEqual(look.outlineWidth, 7)
        XCTAssertEqual(look.fillWidth, 3)
        XCTAssertEqual(look.endRadius(pointerScale: 1), 26)
        XCTAssertEqual(look.endRadius(pointerScale: 4), 50)
        XCTAssertEqual(look.side(pointerScale: 1), 2 * (90 + 3.5) + 4)
    }

    func testValuesSnapToTheirStepsAndStayInRange() {
        let locator = makeLocator(makeDefaults().0)
        locator.duration = 1.234
        XCTAssertEqual(locator.duration, 1.2, accuracy: 1e-9)
        locator.duration = 9
        XCTAssertEqual(locator.duration, 2)
        locator.startRadius = 72
        XCTAssertEqual(locator.startRadius, 70)
        locator.startRadius = 10
        XCTAssertEqual(locator.startRadius, 50)
        locator.endSize = 1.46
        XCTAssertEqual(locator.endSize, 1.5, accuracy: 1e-9)
        locator.lineWidth = 0.1
        XCTAssertEqual(locator.lineWidth, 0.5)
        locator.pressGap = 0.62
        XCTAssertEqual(locator.pressGap, 0.6, accuracy: 1e-9)
    }

    func testSnappingTwiceChangesNothing() {
        for value in stride(from: 0.4, through: 2, by: 0.01) {
            let once = PointerLocator.snap(value, step: 0.1, in: LocatorLook.durationRange)
            XCTAssertEqual(PointerLocator.snap(once, step: 0.1, in: LocatorLook.durationRange), once)
        }
    }

    func testSettingsAreRememberedAndOutOfRangeSavesAreClamped() {
        let (defaults, _) = makeDefaults()
        let locator = makeLocator(defaults)
        locator.duration = 1.5
        locator.startRadius = 120
        locator.endSize = 1.8
        locator.lineWidth = 2
        locator.pressGap = 0.45
        let again = makeLocator(defaults)
        XCTAssertEqual(again.look, LocatorLook(duration: 1.5, startRadius: 120, endSize: 1.8, lineWidth: 2))
        XCTAssertEqual(again.pressGap, 0.45, accuracy: 1e-9)

        defaults.set(50, forKey: "pointerLocatorDuration")
        defaults.set(-3, forKey: "pointerLocatorStartRadius")
        let clamped = makeLocator(defaults)
        XCTAssertEqual(clamped.duration, 2)
        XCTAssertEqual(clamped.startRadius, 50)
    }

    func testExportAndImportCarryTheRingSettings() throws {
        let (source, sourceName) = makeDefaults()
        let locator = makeLocator(source)
        locator.duration = 1.6
        locator.startRadius = 140
        locator.endSize = 0.7
        locator.lineWidth = 1.4
        locator.pressGap = 0.35
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = makeLocator(target)
        XCTAssertEqual(restored.look, locator.look)
        XCTAssertEqual(restored.pressGap, 0.35, accuracy: 1e-9)
    }
}

/// The ring's shape over time, shared by the real ring and its preview.
final class LocatorLookTests: XCTestCase {
    func testRingClosesFromStartToEnd() {
        let look = LocatorLook()
        XCTAssertEqual(look.radius(at: 0, pointerScale: 1, reduceMotion: false), 90, accuracy: 1e-6)
        XCTAssertEqual(look.radius(at: 1, pointerScale: 1, reduceMotion: false), 26, accuracy: 1e-6)
        let half = look.radius(at: 0.5, pointerScale: 1, reduceMotion: false)
        XCTAssertLessThan(half, 26 + (90 - 26) / 2, "eases out: more than halfway there at half time")
    }

    func testReduceMotionKeepsTheRingAtItsEnd() {
        let look = LocatorLook(startRadius: 140, endSize: 2)
        XCTAssertEqual(look.radius(at: 0, pointerScale: 2, reduceMotion: true), 68, accuracy: 1e-6)
        XCTAssertEqual(look.radius(at: 0.6, pointerScale: 2, reduceMotion: true), 68, accuracy: 1e-6)
    }

    func testFadesOverTheLastQuarter() {
        XCTAssertEqual(LocatorLook.opacity(at: 0.5), 1)
        XCTAssertEqual(LocatorLook.opacity(at: 0.75), 1)
        XCTAssertEqual(LocatorLook.opacity(at: 0.875), 0.5, accuracy: 1e-9)
        XCTAssertEqual(LocatorLook.opacity(at: 1), 0)
    }

    func testWindowFitsTheWidestRingAndItsOutline() {
        let wide = LocatorLook(startRadius: 150, lineWidth: 2)
        XCTAssertGreaterThanOrEqual(wide.side(pointerScale: 1), 2 * (150 + 7))
        // A big pointer with the largest end can be wider than a small start.
        let bigEnd = LocatorLook(startRadius: 50, endSize: 2)
        XCTAssertGreaterThanOrEqual(bigEnd.side(pointerScale: 4), 2 * (100 + 3.5))
    }
}

/// The double press waits as long as the gap setting allows.
final class DoubleTapGapTests: XCTestCase {
    private func tap(_ taps: inout DoubleTap, at time: TimeInterval) -> Bool {
        _ = taps.handle(held: .control, key: .control, at: time)
        return taps.handle(held: [], key: .control, at: time + 0.1)
    }

    func testShorterGapRejectsSlowPresses() {
        var taps = DoubleTap()
        taps.longestGap = 0.4
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertFalse(tap(&taps, at: 0.6))
        XCTAssertTrue(tap(&taps, at: 0.9))
    }

    func testLongerGapAcceptsSlowPresses() {
        var taps = DoubleTap()
        taps.longestGap = 1.5
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertTrue(tap(&taps, at: 1.3))
    }
}
