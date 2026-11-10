import CoreGraphics
import XCTest
@testable import PointerColors

/// Hover focus's delay and pause keys. Hover focus stays off in every test, so no event tap starts.
@MainActor
final class HoverFocusTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "HoverFocusTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (defaults, name)
    }

    func testStartsAtTheValuesUsedBefore() {
        let focus = HoverFocus(defaults: makeDefaults().0)
        XCTAssertEqual(focus.delay, 0.12)
        XCTAssertEqual(focus.pauseKeys, .all)
        XCTAssertEqual(focus.pauseKeys.flags, [.maskControl, .maskCommand, .maskAlternate, .maskShift])
    }

    func testDelaySnapsToHundredthsAndRangeThenSaves() {
        let (defaults, _) = makeDefaults()
        let focus = HoverFocus(defaults: defaults)
        focus.delay = 0.337
        XCTAssertEqual(focus.delay, 0.34)
        XCTAssertEqual(defaults.double(forKey: "hoverFocusDelay"), 0.34)
        focus.delay = 5
        XCTAssertEqual(focus.delay, 1)
        focus.delay = 0
        XCTAssertEqual(focus.delay, 0.05)
        XCTAssertEqual(defaults.double(forKey: "hoverFocusDelay"), 0.05)
    }

    func testSnappingIsStableAcrossTheRange() {
        for hundredths in 5...100 {
            let value = HoverFocus.snapped(Double(hundredths) / 100)
            XCTAssertEqual(HoverFocus.snapped(value), value, "\(hundredths)")
        }
    }

    func testSavedValuesLoad() {
        let (defaults, _) = makeDefaults()
        defaults.set(0.5, forKey: "hoverFocusDelay")
        defaults.set(HoverPauseKeys.command.rawValue, forKey: "hoverFocusPauseKeys")
        let focus = HoverFocus(defaults: defaults)
        XCTAssertEqual(focus.delay, 0.5)
        XCTAssertEqual(focus.pauseKeys, .command)
    }

    func testOutOfRangeSavedDelayIsClamped() {
        let (defaults, _) = makeDefaults()
        defaults.set(9.0, forKey: "hoverFocusDelay")
        XCTAssertEqual(HoverFocus(defaults: defaults).delay, 1)
    }

    func testNoPauseKeysIsKeptApartFromUnset() {
        let (defaults, _) = makeDefaults()
        let focus = HoverFocus(defaults: defaults)
        focus.pauseKeys = []
        XCTAssertEqual(HoverFocus(defaults: defaults).pauseKeys, [])
        XCTAssertEqual(focus.pauseKeys.flags, [])
    }

    func testPauseKeyToggles() {
        var keys = HoverPauseKeys.all
        keys.set(.shift, false)
        XCTAssertEqual(keys.flags, [.maskControl, .maskCommand, .maskAlternate])
        keys.set(.shift, true)
        XCTAssertEqual(keys, .all)
    }

    func testUnknownSavedBitsAreDropped() {
        XCTAssertEqual(HoverPauseKeys(saved: 0xFF), .all)
    }

    func testBackupRoundTripsDelayAndPauseKeys() throws {
        let (source, sourceName) = makeDefaults()
        let focus = HoverFocus(defaults: source)
        focus.delay = 0.4
        focus.pauseKeys = [.command, .option]
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = HoverFocus(defaults: target)
        XCTAssertEqual(restored.delay, 0.4)
        XCTAssertEqual(restored.pauseKeys, [.command, .option])
    }
}
