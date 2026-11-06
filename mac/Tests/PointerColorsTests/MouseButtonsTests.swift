import XCTest
@testable import PointerColors

final class ClickDebouncerTests: XCTestCase {
    func testSeparateClicksPass() {
        var debouncer = ClickDebouncer(window: 0.05)
        XCTAssertTrue(debouncer.press(at: 0))
        XCTAssertTrue(debouncer.release(at: 0.08))
        XCTAssertTrue(debouncer.press(at: 0.2))
        XCTAssertTrue(debouncer.release(at: 0.28))
    }

    func testBounceAfterReleaseIsDroppedWithItsRelease() {
        var debouncer = ClickDebouncer(window: 0.05)
        XCTAssertTrue(debouncer.press(at: 0))
        XCTAssertTrue(debouncer.release(at: 0.08))
        XCTAssertFalse(debouncer.press(at: 0.09))
        XCTAssertFalse(debouncer.release(at: 0.1))
        XCTAssertTrue(debouncer.press(at: 0.3))
    }

    func testBounceWhileHeldEndsAsOneClick() {
        var debouncer = ClickDebouncer(window: 0.05)
        XCTAssertTrue(debouncer.press(at: 0))
        XCTAssertTrue(debouncer.release(at: 0.2))
        XCTAssertFalse(debouncer.press(at: 0.205))
        XCTAssertFalse(debouncer.release(at: 0.6))
    }

    func testDeliberateDoubleClickPasses() {
        var debouncer = ClickDebouncer(window: 0.05)
        XCTAssertTrue(debouncer.press(at: 0))
        XCTAssertTrue(debouncer.release(at: 0.07))
        XCTAssertTrue(debouncer.press(at: 0.15))
        XCTAssertTrue(debouncer.release(at: 0.22))
    }
}

final class SideButtonNavigationTests: XCTestCase {
    func testAppleAppsAndListedBrowsersNavigate() {
        XCTAssertTrue(SideButtonNavigation.navigates("com.apple.Safari"))
        XCTAssertTrue(SideButtonNavigation.navigates("com.apple.finder"))
        XCTAssertTrue(SideButtonNavigation.navigates("org.mozilla.firefox"))
        XCTAssertTrue(SideButtonNavigation.navigates("com.binarynights.ForkLift-3"))
    }

    func testAppsThatHandleButtonsKeepThem() {
        XCTAssertFalse(SideButtonNavigation.navigates("com.google.Chrome"))
        XCTAssertFalse(SideButtonNavigation.navigates("com.microsoft.VSCode"))
        XCTAssertFalse(SideButtonNavigation.navigates(nil))
    }
}

final class HoverEntriesTests: XCTestCase {
    private let a = WindowFocus.Target(pid: 1, windowID: 10)
    private let b = WindowFocus.Target(pid: 2, windowID: 20)

    func testOneAttemptPerVisit() {
        var entries = HoverEntries()
        XCTAssertTrue(entries.enter(a))
        entries.consume()
        XCTAssertFalse(entries.enter(a))
        XCTAssertTrue(entries.enter(b))
        entries.consume()
        XCTAssertTrue(entries.enter(a))
    }

    func testClickConsumesTheVisit() {
        var entries = HoverEntries()
        XCTAssertTrue(entries.enter(a))
        entries.consume()
        XCTAssertFalse(entries.enter(a))
    }
}

@MainActor
final class NavigationAppsTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "NavigationAppsTests")
        defaults.removePersistentDomain(forName: "NavigationAppsTests")
    }

    private func buttons() -> MouseButtons { MouseButtons(defaults: defaults) }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "NavigationAppsTests")
    }

    func testFreshInstallListsFinderWithItsGoKeys() {
        let finder = buttons().navigationApps.first { $0.bundleID == "com.apple.finder" }
        XCTAssertEqual(finder?.back?.keyLabel, "[")
        XCTAssertEqual(finder?.forward?.keyLabel, "]")
        XCTAssertEqual(finder?.isOn, true)
    }

    func testSavedListFromBeforeFinderGetsFinderAddedOnce() throws {
        let slack = NavigationApp.defaults.first { $0.name == "Slack" }!
        defaults.set(try JSONEncoder().encode([slack]), forKey: "sideButtonApps")
        let model = buttons()
        XCTAssertEqual(model.navigationApps.map(\.name), ["Finder", "Slack", "Claude"])
        model.removeNavigationApp("com.apple.finder")
        XCTAssertEqual(buttons().navigationApps.map(\.name), ["Slack", "Claude"])
    }

    func testFreshInstallListsClaudeWithItsBackAndForwardKeys() {
        let claude = buttons().navigationApps.first { $0.bundleID == "com.anthropic.claudefordesktop" }
        XCTAssertEqual(claude?.back?.keyLabel, "[")
        XCTAssertEqual(claude?.forward?.keyLabel, "]")
    }

    func testFreshInstallListsEveryBuiltInApp() {
        XCTAssertEqual(buttons().navigationApps.map(\.name), ["Finder", "Claude", "Slack"])
    }

    func testFinderTurnedOffStaysOff() {
        buttons().changeNavigationApp("com.apple.finder") { $0.isOn = false }
        let finder = buttons().navigationApps.first { $0.bundleID == "com.apple.finder" }
        XCTAssertEqual(finder?.isOn, false)
    }
}
