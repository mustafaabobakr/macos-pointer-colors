import XCTest
@testable import PointerColors

/// The defaults the reset buttons put back come from models as they start out.
@MainActor
final class SettingsResetTests: XCTestCase {
    func testFactoriesStartAtTheirDefaults() {
        let fresh = PointerHighlight(defaults: UserDefaults(suiteName: "SettingsResetTests-\(UUID().uuidString)")!)
        XCTAssertEqual(PointerHighlight.factory.pulseSize, fresh.pulseSize)
        XCTAssertEqual(PointerHighlight.factory.bokehSpeed, 0.55)
        XCTAssertEqual(PointerHighlight.factory.bokehBlur, 1)
        XCTAssertEqual(PointerHighlight.factory.bokehColorSource, .clip)
        XCTAssertEqual(PointerHighlight.factory.pulseStyle, fresh.pulseStyle)
        XCTAssertFalse(MagicMouseZoom.defaultIsOn)
    }

    func testFactoriesIgnoreTheUsersOwnChanges() {
        let highlight = PointerHighlight.factory
        XCTAssertEqual(highlight.pulseDuration, PointerHighlight(defaults: FactoryDefaults.make("check")).pulseDuration)
    }
}

/// Each pulse style card resets only its own style's settings.
@MainActor
final class PulseStyleResetTests: XCTestCase {
    private func fresh() -> PointerHighlight {
        PointerHighlight(defaults: UserDefaults(suiteName: "PulseStyleReset-\(UUID().uuidString)")!)
    }

    func testAFreshStyleIsUnchanged() {
        let highlight = fresh()
        for style in PulseStyle.allCases { XCTAssertFalse(highlight.isChanged(style), "\(style)") }
    }

    func testResettingOneStyleLeavesTheOthersAndSize() {
        let highlight = fresh()
        highlight.frostShards = 11
        highlight.frostDuration = 1.3
        highlight.bokehBlur = 0
        highlight.pulseSize = 1.6
        XCTAssertTrue(highlight.isChanged(.frost))
        XCTAssertTrue(highlight.isChanged(.bokeh))
        XCTAssertFalse(highlight.isChanged(.ring), "Size is shared, not Ring's own")
        highlight.reset(.frost)
        XCTAssertFalse(highlight.isChanged(.frost))
        XCTAssertEqual(highlight.frostShards, PointerHighlight.factory.frostShards)
        XCTAssertEqual(highlight.frostDuration, PointerHighlight.factory.frostDuration)
        XCTAssertEqual(highlight.bokehBlur, 0, "Bokeh keeps its change")
        XCTAssertEqual(highlight.pulseSize, 1.6, "Size stays")
    }

    func testRingAndRippleShareColorOutlineAndLength() {
        let highlight = fresh()
        highlight.pulseDuration = 1.1
        XCTAssertTrue(highlight.isChanged(.ring))
        XCTAssertTrue(highlight.isChanged(.ripple))
        highlight.reset(.ripple)
        XCTAssertFalse(highlight.isChanged(.ring))
    }
}
