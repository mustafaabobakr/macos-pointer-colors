import XCTest
@testable import PointerColors

/// The battery levels, notification, label and report values that became settings: they start
/// at what earlier builds chose, are saved, round-trip through a backup, and reach what's drawn.
@MainActor
final class BatterySettingsTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "BatterySettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (defaults, name)
    }

    func testStartsAtTheValuesUsedBefore() {
        let (defaults, _) = makeDefaults()
        let battery = BatterySettings(defaults: defaults)
        XCTAssertFalse(battery.alertsOn)
        XCTAssertEqual(battery.alertLevel, 10)
        XCTAssertTrue(battery.alertSound)
        XCTAssertFalse(battery.remindsAgain)
        XCTAssertEqual(battery.reminderStep, 5)
        XCTAssertEqual(battery.lowLevel, 20)
        XCTAssertEqual(battery.labelPosition, .belowRight)
        XCTAssertEqual(battery.wearShare, 0.15)
        XCTAssertEqual(battery.useDays, 7)
        XCTAssertEqual(battery.chartDays, 60)
    }

    func testReadsTheOldAlertMenu() {
        let (defaults, _) = makeDefaults()
        defaults.set("below20", forKey: "batteryAlert")
        let battery = BatterySettings(defaults: defaults)
        XCTAssertTrue(battery.alertsOn)
        XCTAssertEqual(battery.alertLevel, 20)

        let (off, _) = makeDefaults()
        off.set("off", forKey: "batteryAlert")
        XCTAssertFalse(BatterySettings(defaults: off).alertsOn)
    }

    func testReadsTheOldShowMenus() {
        let (ten, _) = makeDefaults()
        ten.set("below10", forKey: "dockBattery")
        XCTAssertEqual(BatterySettings(defaults: ten).lowLevel, 10)
        XCTAssertEqual(AppSettings(defaults: ten).dockBattery, .whenLow)

        // Where both were used, the higher one, so nothing that showed stops showing.
        let (both, _) = makeDefaults()
        both.set("below10", forKey: "dockBattery")
        both.set("below20", forKey: "pointerBattery")
        XCTAssertEqual(BatterySettings(defaults: both).lowLevel, 20)
    }

    func testKeepsTheReadLevelOnceAMenuChanges() {
        let (defaults, _) = makeDefaults()
        defaults.set("below10", forKey: "batteryDisplay")
        _ = BatterySettings(defaults: defaults)
        defaults.set("always", forKey: "batteryDisplay")
        XCTAssertEqual(BatterySettings(defaults: defaults).lowLevel, 10)
    }

    func testSavesEachChange() {
        let (defaults, _) = makeDefaults()
        let battery = BatterySettings(defaults: defaults)
        battery.alertsOn = true
        battery.alertLevel = 35
        battery.alertSound = false
        battery.remindsAgain = true
        battery.reminderStep = 3
        battery.lowLevel = 42
        battery.labelPosition = .aboveLeft
        battery.wearShare = 0.3
        battery.useDays = 14
        battery.chartDays = 120

        let read = BatterySettings(defaults: defaults)
        XCTAssertEqual([read.alertsOn, read.alertSound, read.remindsAgain], [true, false, true])
        XCTAssertEqual([read.alertLevel, read.reminderStep, read.lowLevel, read.wearShare, read.useDays, read.chartDays],
                       [35, 3, 42, 0.3, 14, 120])
        XCTAssertEqual(read.labelPosition, .aboveLeft)
    }

    func testBackupRoundTripCarriesTheSettings() throws {
        let (source, sourceName) = makeDefaults()
        let battery = BatterySettings(defaults: source)
        battery.alertLevel = 33
        battery.remindsAgain = true
        battery.labelPosition = .belowLeft
        battery.chartDays = 180
        let folder = FileManager.default.temporaryDirectory.appending(path: sourceName, directoryHint: .isDirectory)
        let data = try SettingsBackup(defaults: source, domain: sourceName, historyFolder: folder).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName, historyFolder: folder).restore(from: data)
        let read = BatterySettings(defaults: target)
        XCTAssertEqual(read.alertLevel, 33)
        XCTAssertTrue(read.remindsAgain)
        XCTAssertEqual(read.labelPosition, .belowLeft)
        XCTAssertEqual(read.chartDays, 180)
    }

    func testRedFollowsTheAlertOrTheLowLevel() {
        let (defaults, _) = makeDefaults()
        let battery = BatterySettings(defaults: defaults)
        battery.lowLevel = 30
        battery.alertLevel = 12
        XCTAssertEqual(battery.redLevel, 30, "Alert off: the low level")
        battery.alertsOn = true
        XCTAssertEqual(battery.redLevel, 12)
    }

    func testWhenLowShowsBelowTheLevel() {
        XCTAssertTrue(BatteryDisplay.whenLow.shows(34, low: 35))
        XCTAssertFalse(BatteryDisplay.whenLow.shows(35, low: 35))
        XCTAssertTrue(BatteryDisplay.always.shows(90, low: 35))
        XCTAssertFalse(BatteryDisplay.off.shows(1, low: 35))
        XCTAssertFalse(BatteryDisplay.always.shows(nil, low: 35))
    }

    func testNotifiesOnceOrAtEachStepLower() {
        XCTAssertTrue(BatteryNotifier.isDue(level: 19, alertedAt: nil, remindStep: nil))
        XCTAssertFalse(BatteryNotifier.isDue(level: 5, alertedAt: 19, remindStep: nil), "Once, without reminders")
        XCTAssertFalse(BatteryNotifier.isDue(level: 15, alertedAt: 19, remindStep: 5))
        XCTAssertTrue(BatteryNotifier.isDue(level: 14, alertedAt: 19, remindStep: 5))
        XCTAssertTrue(BatteryNotifier.isDue(level: 18, alertedAt: 19, remindStep: 1))
    }

    func testLabelSitsOnTheChosenSide() {
        let size = CGSize(width: 50, height: 20)
        XCTAssertEqual(BatteryLabelPosition.belowRight.offset(for: size), CGPoint(x: 14, y: 30), "As before")
        XCTAssertEqual(BatteryLabelPosition.belowLeft.offset(for: size), CGPoint(x: -64, y: 30))
        XCTAssertEqual(BatteryLabelPosition.aboveRight.offset(for: size), CGPoint(x: 14, y: -34))
        XCTAssertEqual(BatteryLabelPosition.aboveLeft.offset(for: size), CGPoint(x: -64, y: -34))
        XCTAssertEqual(BatteryLabelPosition.belowRight.flipped(horizontally: true, vertically: false), .belowLeft)
        XCTAssertEqual(BatteryLabelPosition.aboveLeft.flipped(horizontally: true, vertically: true), .belowRight)
        XCTAssertEqual(BatteryLabelPosition.belowLeft.flipped(horizontally: false, vertically: true), .aboveLeft)
    }
}

extension BatterySettingsTests {
    func testKeepsPercentsAndDaysWhole() {
        let (defaults, _) = makeDefaultsForRounding()
        let battery = BatterySettings(defaults: defaults)
        battery.alertLevel = 23.6
        battery.lowLevel = 31.2
        battery.reminderStep = 4.5
        battery.useDays = 9.4
        XCTAssertEqual([battery.alertLevel, battery.lowLevel, battery.reminderStep, battery.useDays], [24, 31, 5, 9])
        XCTAssertEqual(BatterySettings(defaults: defaults).alertLevel, 24)
    }

    private func makeDefaultsForRounding() -> (UserDefaults, String) {
        let name = "BatterySettingsRounding-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (defaults, name)
    }
}
