import XCTest
@testable import PointerColors

/// Laser screenshots: the area they keep, where it lands on a display, and their settings.
@MainActor
final class LaserShotTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "LaserShotTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    // MARK: Area

    func testAreaGrowsByReachAndMarginOnEverySide() {
        let trail = CGRect(x: 100, y: 200, width: 50, height: 30)
        XCTAssertEqual(LaserShotArea.area(around: trail, reach: 7, margin: 20),
                       CGRect(x: 73, y: 173, width: 104, height: 84))
        XCTAssertEqual(LaserShotArea.area(around: trail, reach: 0, margin: 0), trail)
    }

    func testClicksAndTinyDragsTakeNoScreenshot() {
        XCTAssertNil(LaserShotArea.area(around: CGRect(x: 5, y: 5, width: 0, height: 0), reach: 7, margin: 20))
        XCTAssertNil(LaserShotArea.area(around: CGRect(x: 5, y: 5, width: 9, height: 9), reach: 7, margin: 20))
        XCTAssertNotNil(LaserShotArea.area(around: CGRect(x: 5, y: 5, width: 10, height: 0), reach: 7, margin: 20),
                        "a straight line counts")
    }

    func testSourceRectIsTopLeftAndCutToTheDisplay() {
        let display = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // 100 from the left and 50 from the bottom: 800 - 150 = 650 from the top.
        XCTAssertEqual(LaserShotArea.sourceRect(CGRect(x: 100, y: 50, width: 200, height: 100), on: display),
                       CGRect(x: 100, y: 650, width: 200, height: 100))
        // Past the left and top edges: only what's on the display.
        XCTAssertEqual(LaserShotArea.sourceRect(CGRect(x: -40, y: 750, width: 100, height: 100), on: display),
                       CGRect(x: 0, y: 0, width: 60, height: 50))
        XCTAssertNil(LaserShotArea.sourceRect(CGRect(x: 2000, y: 0, width: 10, height: 10), on: display))
    }

    func testSourceRectOnASecondDisplay() {
        // A display to the right of and above the main one.
        let display = CGRect(x: 1000, y: 200, width: 1600, height: 900)
        XCTAssertEqual(LaserShotArea.sourceRect(CGRect(x: 1100, y: 1000, width: 50, height: 40), on: display),
                       CGRect(x: 100, y: 60, width: 50, height: 40))
    }

    func testDisplayHoldingMostOfTheArea() {
        let frames = [CGRect(x: 0, y: 0, width: 1000, height: 800), CGRect(x: 1000, y: 0, width: 1000, height: 800)]
        XCTAssertEqual(LaserShotArea.displayIndex(for: CGRect(x: 950, y: 10, width: 100, height: 10), among: frames), 0,
                       "a tie goes to the first")
        XCTAssertEqual(LaserShotArea.displayIndex(for: CGRect(x: 980, y: 10, width: 100, height: 10), among: frames), 1)
        XCTAssertNil(LaserShotArea.displayIndex(for: CGRect(x: 5000, y: 0, width: 10, height: 10), among: frames))
    }

    // MARK: Settings

    func testStartsOffWithClipboardFolderAndTrail() {
        let highlight = PointerHighlight(defaults: makeDefaults().0)
        XCTAssertFalse(highlight.laserShotOn)
        XCTAssertEqual(highlight.laserShotMargin, 20)
        XCTAssertTrue(highlight.laserShotIncludesTrail)
        XCTAssertTrue(highlight.laserShotCopies)
        XCTAssertTrue(highlight.laserShotSaves)
        XCTAssertTrue(highlight.laserShotFolder.hasSuffix("/Desktop") || highlight.laserShotFolder.hasSuffix("/Desktop/"))
        XCTAssertEqual(highlight.laserShotOpener, LaserShotOpener.none)
        XCTAssertEqual(highlight.laserShotZoomOut, .both)
        XCTAssertTrue(highlight.laserShotWholeZoom)
        XCTAssertTrue(highlight.laserShotOnlyZoomed)
    }

    func testOnlyWhileZoomedSkipsShotsWithoutAZoom() {
        let highlight = PointerHighlight(defaults: makeDefaults().0)
        XCTAssertFalse(highlight.takesLaserShot(zoomed: true), "screenshots off")
        highlight.laserShotOn = true
        XCTAssertTrue(highlight.takesLaserShot(zoomed: true))
        XCTAssertFalse(highlight.takesLaserShot(zoomed: false))
        highlight.laserShotOnlyZoomed = false
        XCTAssertTrue(highlight.takesLaserShot(zoomed: false))
        XCTAssertTrue(highlight.takesLaserShot(zoomed: true))
    }

    func testOffTakesNoShot() {
        let highlight = PointerHighlight(defaults: makeDefaults().0)
        XCTAssertNil(LaserShot(settings: highlight, trail: CGRect(x: 0, y: 0, width: 100, height: 100), reach: 7, overlayWindows: []))
        highlight.laserShotOn = true
        XCTAssertNotNil(LaserShot(settings: highlight, trail: CGRect(x: 0, y: 0, width: 100, height: 100), reach: 7, overlayWindows: []))
    }

    func testShotTakesTheSettingsOfItsMoment() throws {
        let highlight = PointerHighlight(defaults: makeDefaults().0)
        (highlight.laserShotOn, highlight.laserShotMargin, highlight.laserShotSaves) = (true, 40, false)
        (highlight.laserShotCopies, highlight.laserShotIncludesTrail, highlight.laserShotOpener) = (false, false, .defaultApp)
        let shot = try XCTUnwrap(LaserShot(settings: highlight, trail: CGRect(x: 0, y: 0, width: 100, height: 100),
                                           reach: 5, overlayWindows: [7]))
        XCTAssertEqual(shot.area, CGRect(x: -45, y: -45, width: 190, height: 190))
        XCTAssertNil(shot.folder)
        XCTAssertFalse(shot.copies)
        XCTAssertFalse(shot.includesTrail)
        XCTAssertEqual(shot.opener, .defaultApp)
        XCTAssertEqual(shot.overlayWindows, [7])
        XCTAssertEqual(shot.zoomOut, .both)
        highlight.laserShotZoomOut = .lens
        XCTAssertEqual(LaserShot(settings: highlight, trail: CGRect(x: 0, y: 0, width: 100, height: 100),
                                 reach: 5, overlayWindows: [])?.zoomOut, .lens)
    }

    func testBackupRoundTripCarriesEveryScreenshotSetting() throws {
        let (source, sourceName) = makeDefaults()
        let highlight = PointerHighlight(defaults: source)
        highlight.laserShotOn = true
        highlight.laserShotMargin = 135
        highlight.laserShotIncludesTrail = false
        highlight.laserShotCopies = false
        highlight.laserShotSaves = false
        highlight.laserShotFolder = "/tmp/Laser shots"
        highlight.laserShotOpener = .cleanShot
        highlight.laserShotZoomOut = .wholeScreen
        highlight.laserShotWholeZoom = false
        highlight.laserShotOnlyZoomed = false
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = PointerHighlight(defaults: target)
        XCTAssertTrue(restored.laserShotOn)
        XCTAssertEqual(restored.laserShotMargin, 135)
        XCTAssertFalse(restored.laserShotIncludesTrail)
        XCTAssertFalse(restored.laserShotCopies)
        XCTAssertFalse(restored.laserShotSaves)
        XCTAssertEqual(restored.laserShotFolder, "/tmp/Laser shots")
        XCTAssertEqual(restored.laserShotOpener, .cleanShot)
        XCTAssertEqual(restored.laserShotZoomOut, .wholeScreen)
        XCTAssertFalse(restored.laserShotWholeZoom)
        XCTAssertFalse(restored.laserShotOnlyZoomed)
    }

    // MARK: The app's own folder

    func testStoreCountsAndDeletesOnlyItsScreenshots() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "LaserShotStore-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LaserShotStore(folder: folder)
        XCTAssertEqual(store.usage.count, 0, "no folder yet counts as empty")

        let made = try store.prepared()
        try Data(count: 100).write(to: made.appending(path: "Laser 1.png"))
        try Data(count: 50).write(to: made.appending(path: "Laser 2.PNG"))
        try Data(count: 7).write(to: made.appending(path: "notes.txt"))
        XCTAssertEqual(store.usage.count, 2)
        XCTAssertEqual(store.usage.bytes, 150)

        try store.deleteAll()
        XCTAssertEqual(store.usage.count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: made.appending(path: "notes.txt").path(percentEncoded: false)),
                      "only screenshots are deleted")
    }

    func testStoreLivesInTheAppsFolder() {
        XCTAssertEqual(LaserShotStore().folder.lastPathComponent, "Screenshots")
        XCTAssertEqual(LaserShotStore().folder.deletingLastPathComponent().standardizedFileURL,
                       BatteryHistoryStore.defaultFolder.standardizedFileURL)
    }

    func testZoomOutChoiceEndsTheRightZooms() {
        XCTAssertFalse(LaserShotZoomOut.off.endsZoom(.wholeScreen))
        XCTAssertFalse(LaserShotZoomOut.off.endsZoom(.lens))
        XCTAssertTrue(LaserShotZoomOut.wholeScreen.endsZoom(.wholeScreen))
        XCTAssertFalse(LaserShotZoomOut.wholeScreen.endsZoom(.lens))
        XCTAssertTrue(LaserShotZoomOut.lens.endsZoom(.lens))
        XCTAssertFalse(LaserShotZoomOut.lens.endsZoom(.wholeScreen))
        XCTAssertTrue(LaserShotZoomOut.both.endsZoom(.wholeScreen))
        XCTAssertTrue(LaserShotZoomOut.both.endsZoom(.lens))
    }

    func testWholeZoomShotKeepsTheZoomsAreaWithoutMargin() throws {
        let highlight = PointerHighlight(defaults: makeDefaults().0)
        let lens = CGRect(x: 300, y: 200, width: 400, height: 250)
        XCTAssertNil(LaserShot(settings: highlight, area: lens, overlayWindows: []), "screenshots off")
        highlight.laserShotOn = true
        highlight.laserShotMargin = 80
        XCTAssertEqual(try XCTUnwrap(LaserShot(settings: highlight, area: lens, overlayWindows: [])).area, lens)
    }
}
