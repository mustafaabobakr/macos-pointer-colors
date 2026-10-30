import XCTest
@testable import PointerColors

final class DoubleTapTests: XCTestCase {
    /// Presses and releases `key` at `time`, held for `hold` seconds. True when it completes a double press.
    private func tap(_ taps: inout DoubleTap, _ key: HoldKeys = .control, at time: TimeInterval, hold: TimeInterval = 0.1) -> Bool {
        _ = taps.handle(held: key, key: .control, at: time)
        return taps.handle(held: [], key: .control, at: time + hold)
    }

    func testTwoQuickPressesReveal() {
        var taps = DoubleTap()
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertTrue(tap(&taps, at: 0.3))
    }

    func testPressesTooFarApartDont() {
        var taps = DoubleTap()
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertFalse(tap(&taps, at: 1.5))
        XCTAssertTrue(tap(&taps, at: 1.8))
    }

    func testLongPressDoesntCount() {
        var taps = DoubleTap()
        XCTAssertFalse(tap(&taps, at: 0, hold: 0.6))
        XCTAssertFalse(tap(&taps, at: 0.8))
    }

    func testOtherModifierDoesntCount() {
        var taps = DoubleTap()
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertFalse(tap(&taps, .option, at: 0.3))
        XCTAssertFalse(tap(&taps, at: 0.5))
    }

    func testControlWithAnotherModifierDoesntCount() {
        var taps = DoubleTap()
        XCTAssertFalse(tap(&taps, at: 0))
        _ = taps.handle(held: .control, key: .control, at: 0.3)
        _ = taps.handle(held: [.control, .shift], key: .control, at: 0.35)
        XCTAssertFalse(taps.handle(held: [], key: .control, at: 0.4))
    }

    func testThirdPressStartsOver() {
        var taps = DoubleTap()
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertTrue(tap(&taps, at: 0.3))
        XCTAssertFalse(tap(&taps, at: 0.6))
    }

    func testSpeedScaleRoundTrips() {
        for speed in [0.0, 0.25, 0.5, 1.0] {
            XCTAssertEqual(MouseTracking.speed(fromResolution: MouseTracking.resolution(fromSpeed: speed)), speed, accuracy: 0.0001)
        }
        XCTAssertEqual(MouseTracking.resolution(fromSpeed: 1), 40, accuracy: 0.001)
        XCTAssertEqual(MouseTracking.resolution(fromSpeed: 0), 1200, accuracy: 0.001)
    }
}
