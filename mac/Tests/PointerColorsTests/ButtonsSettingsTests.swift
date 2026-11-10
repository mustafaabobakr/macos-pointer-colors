import XCTest
@testable import PointerColors

@MainActor
final class ButtonsSettingsTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "ButtonsSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (defaults, name)
    }

    func testFreshInstallKeepsTodaysValues() {
        let (defaults, _) = makeDefaults()
        let buttons = MouseButtons(defaults: defaults)
        XCTAssertFalse(buttons.swipesNavigate)
        XCTAssertEqual(buttons.swipeDistance, 80)
        XCTAssertEqual(buttons.backButton, 3)
        XCTAssertEqual(buttons.forwardButton, 4)
        XCTAssertEqual(buttons.doubleClickButtons, .leftAndRight)
    }

    /// Before the swipe had its own switch it followed the side buttons'.
    func testSwipeSwitchMigratesFromSideButtons() {
        let (defaults, _) = makeDefaults()
        defaults.set(true, forKey: "sideButtonsNavigate")
        XCTAssertTrue(MouseButtons(defaults: defaults).swipesNavigate)

        // Saved at once, so turning the side buttons off later leaves the swipe on.
        MouseButtons(defaults: defaults).sideButtonsNavigate = false
        let later = MouseButtons(defaults: defaults)
        XCTAssertFalse(later.sideButtonsNavigate)
        XCTAssertTrue(later.swipesNavigate)
    }

    func testSwipeSwitchIsIndependent() {
        let (defaults, _) = makeDefaults()
        let buttons = MouseButtons(defaults: defaults)
        buttons.sideButtonsNavigate = true
        buttons.swipesNavigate = false
        let reloaded = MouseButtons(defaults: defaults)
        XCTAssertTrue(reloaded.sideButtonsNavigate)
        XCTAssertFalse(reloaded.swipesNavigate)
    }

    func testSwipeDistanceSnapsToStepWithinRange() {
        let (defaults, _) = makeDefaults()
        let buttons = MouseButtons(defaults: defaults)
        buttons.swipeDistance = 123.4
        XCTAssertEqual(buttons.swipeDistance, 120)
        buttons.swipeDistance = 500
        XCTAssertEqual(buttons.swipeDistance, 200)
        buttons.swipeDistance = 1
        XCTAssertEqual(buttons.swipeDistance, 40)
        XCTAssertEqual(MouseButtons(defaults: defaults).swipeDistance, 40)
    }

    func testOutOfRangeSavedDistanceIsClampedOnLoad() {
        let (defaults, _) = makeDefaults()
        defaults.set(999.0, forKey: "magicMouseSwipeDistance")
        XCTAssertEqual(MouseButtons(defaults: defaults).swipeDistance, 200)
    }

    func testRecordingTheOtherButtonSwapsThem() {
        let (defaults, _) = makeDefaults()
        let buttons = MouseButtons(defaults: defaults)
        buttons.setBackButton(4)
        XCTAssertEqual(buttons.backButton, 4)
        XCTAssertEqual(buttons.forwardButton, 3)
        buttons.setForwardButton(4)
        XCTAssertEqual(buttons.backButton, 3)
        XCTAssertEqual(buttons.forwardButton, 4)
    }

    func testRecordedButtonsSaveAndReset() {
        let (defaults, _) = makeDefaults()
        let buttons = MouseButtons(defaults: defaults)
        buttons.setBackButton(5)
        buttons.setForwardButton(6)
        let reloaded = MouseButtons(defaults: defaults)
        XCTAssertEqual(reloaded.backButton, 5)
        XCTAssertEqual(reloaded.forwardButton, 6)
        reloaded.resetNavigationButtons()
        XCTAssertEqual(MouseButtons(defaults: defaults).backButton, 3)
        XCTAssertEqual(MouseButtons(defaults: defaults).forwardButton, 4)
    }

    /// A left or right click saved by hand never becomes back or forward.
    func testSavedLeftOrRightClickIsIgnored() {
        let (defaults, _) = makeDefaults()
        defaults.set(0, forKey: "backMouseButton")
        defaults.set(1, forKey: "forwardMouseButton")
        let buttons = MouseButtons(defaults: defaults)
        XCTAssertEqual(buttons.backButton, 3)
        XCTAssertEqual(buttons.forwardButton, 4)
    }

    func testDoubleClickButtonsWatchTheRightEvents() {
        XCTAssertEqual(DoubleClickButtons.left.eventTypes, [.leftMouseDown, .leftMouseUp])
        XCTAssertEqual(DoubleClickButtons.leftAndRight.eventTypes,
                       [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp])
    }

    func testBackupRoundTripCarriesEveryButtonsSetting() throws {
        let (source, sourceName) = makeDefaults()
        let buttons = MouseButtons(defaults: source)
        buttons.sideButtonsNavigate = true
        buttons.swipesNavigate = false
        buttons.swipeDistance = 150
        buttons.setBackButton(5)
        buttons.setForwardButton(2)
        buttons.doubleClickButtons = .left
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = MouseButtons(defaults: target)
        XCTAssertTrue(restored.sideButtonsNavigate)
        XCTAssertFalse(restored.swipesNavigate)
        XCTAssertEqual(restored.swipeDistance, 150)
        XCTAssertEqual(restored.backButton, 5)
        XCTAssertEqual(restored.forwardButton, 2)
        XCTAssertEqual(restored.doubleClickButtons, .left)
    }

    /// A file from before the swipe switch, with the side buttons on, turns the swipe on too.
    func testOldBackupMigratesTheSwipeSwitch() throws {
        let (old, oldName) = makeDefaults()
        old.set(true, forKey: "sideButtonsNavigate")
        let data = try SettingsBackup(defaults: old, domain: oldName).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        MouseButtons(defaults: target).swipesNavigate = false
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        XCTAssertTrue(MouseButtons(defaults: target).swipesNavigate)
    }

    func testSearchFindsTheNewSettings() {
        let anchors = SettingsSearch.results(for: "swipe distance").compactMap(\.anchor)
        XCTAssertEqual(anchors, ["buttons.swipe"])
        XCTAssertTrue(SettingsSearch.results(for: "button numbers").contains { $0.anchor == "buttons.side" })
    }
}

final class MouseButtonRecorderTests: XCTestCase {
    func testButtonNamesCountFromOne() {
        XCTAssertEqual(MouseButtonRecorder.name(of: 3), "Button 4")
    }
}
