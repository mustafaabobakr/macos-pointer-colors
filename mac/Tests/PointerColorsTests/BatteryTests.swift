import XCTest
@testable import PointerColors

final class BatteryHistoryTests: XCTestCase {
    private let day: TimeInterval = 86_400

    private func reading(_ level: Int, charging: Bool = false) -> MouseBatteryReading {
        MouseBatteryReading(id: "mouse", name: "Magic Mouse", level: level, isCharging: charging)
    }

    func testChargingEndsTheChargeAndKeepsItsDrain() throws {
        var history = BatteryHistory()
        let start = Date(timeIntervalSince1970: 0)
        history.record([reading(100)], at: start)
        history.record([reading(60)], at: start + 10 * day)
        // Plugged in at 60: macOS says so before the level has climbed.
        history.record([reading(60, charging: true)], at: start + 10 * day + 60)
        history.record([reading(80, charging: true)], at: start + 10 * day + 1_800)

        let mouse = try XCTUnwrap(history.mice.first)
        XCTAssertEqual(mouse.past.count, 1)
        XCTAssertEqual(mouse.past.first?.used, 40)
        XCTAssertEqual(mouse.current.used, 0, "Charging isn't drain")
    }

    func testChargeStartsCountingOnceUnplugged() throws {
        var history = BatteryHistory()
        let start = Date(timeIntervalSince1970: 0)
        history.record([reading(90, charging: true)], at: start)
        history.record([reading(100)], at: start + 3_600)
        history.record([reading(90)], at: start + 2 * day)

        let mouse = try XCTUnwrap(history.mice.first)
        XCTAssertEqual(mouse.current.start.level, 100)
        XCTAssertEqual(mouse.current.used, 10)
    }

    @MainActor
    func testRisingLevelCountsAsCharging() {
        let before = [reading(40)]
        XCTAssertTrue(PointerTracking.markRising([reading(42)], since: before)[0].isCharging)
        XCTAssertFalse(PointerTracking.markRising([reading(41)], since: before)[0].isCharging, "A wobble of 1 isn't a charge")
        XCTAssertFalse(PointerTracking.markRising([reading(39)], since: before)[0].isCharging)
        XCTAssertTrue(PointerTracking.markRising([reading(39, charging: true)], since: before)[0].isCharging)
    }
}

final class BatteryHistoryStoreTests: XCTestCase {
    private func makeStore() -> (BatteryHistoryStore, UserDefaults) {
        let name = "BatteryHistoryStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let folder = FileManager.default.temporaryDirectory.appending(path: name, directoryHint: .isDirectory)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: folder)
        }
        return (BatteryHistoryStore(defaults: defaults, folder: folder), defaults)
    }

    private func sampleHistory() -> BatteryHistory {
        var history = BatteryHistory()
        history.record([MouseBatteryReading(id: "mouse", name: "Magic Mouse", level: 100)], at: Date(timeIntervalSince1970: 0))
        history.record([MouseBatteryReading(id: "mouse", name: "Magic Mouse", level: 70)], at: Date(timeIntervalSince1970: 86_400))
        return history
    }

    func testSavesAndLoadsFromItsFile() {
        let (store, defaults) = makeStore()
        store.save(sampleHistory())
        XCTAssertEqual(store.load(), sampleHistory())
        XCTAssertNil(defaults.object(forKey: BatteryHistoryStore.defaultsKey), "Kept out of the defaults")
    }

    /// The history older versions kept in the defaults moves into the file and out of the defaults.
    func testMovesTheHistoryFromTheDefaults() throws {
        let (store, defaults) = makeStore()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(sampleHistory()), forKey: BatteryHistoryStore.defaultsKey)

        XCTAssertEqual(store.load(), sampleHistory())
        XCTAssertNil(defaults.object(forKey: BatteryHistoryStore.defaultsKey))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testSetsAsideAFileItCantRead() throws {
        let (store, _) = makeStore()
        let folder = store.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: store.fileURL)

        XCTAssertEqual(store.load(), BatteryHistory())
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("battery-history-unreadable-") }, "Kept, not written over")
    }

    /// Export carries the history, and importing puts it back through the defaults into the file.
    func testBackupRoundTripCarriesTheHistory() throws {
        let (source, sourceDefaults) = makeStore()
        source.save(sampleHistory())
        let sourceName = "BatteryBackupSource-\(UUID().uuidString)"
        let data = try SettingsBackup(defaults: sourceDefaults, domain: sourceName,
                                      historyFolder: source.fileURL.deletingLastPathComponent())
            .export(launchAtLogin: false)

        let (target, targetDefaults) = makeStore()
        try SettingsBackup(defaults: targetDefaults, domain: "BatteryBackupTarget-\(UUID().uuidString)",
                           historyFolder: target.fileURL.deletingLastPathComponent()).restore(from: data)
        XCTAssertEqual(target.load(), sampleHistory())
    }
}
