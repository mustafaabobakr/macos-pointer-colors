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
        XCTAssertEqual(mouse.current?.used, 0, "Charging isn't drain")
    }

    func testChargeStartsCountingOnceUnplugged() throws {
        var history = BatteryHistory()
        let start = Date(timeIntervalSince1970: 0)
        history.record([reading(90, charging: true)], at: start)
        history.record([reading(100)], at: start + 3_600)
        history.record([reading(90)], at: start + 2 * day)

        let mouse = try XCTUnwrap(history.mice.first)
        XCTAssertEqual(mouse.current?.start.level, 100)
        XCTAssertEqual(mouse.current?.used, 10)
    }

    func testChargeAgeRunsFromWhenItWasCharged() throws {
        var history = BatteryHistory()
        let start = Date(timeIntervalSince1970: 0)
        history.record([reading(100)], at: start)
        history.record([reading(100)], at: start + day - 3_600)
        history.record([reading(99)], at: start + day)

        let mouse = try XCTUnwrap(history.mice.first)
        XCTAssertEqual(mouse.current?.start.date, start, "Staying at 100% doesn't restart the charge")
        XCTAssertEqual(try XCTUnwrap(mouse.current).days, 1, accuracy: 0.001)
        XCTAssertEqual(mouse.readings.count, 2, "A reading at the same level isn't logged again")
    }

    func testEstimatesAFullChargeFromTheChargeItsOn() throws {
        var history = BatteryHistory()
        let start = Date(timeIntervalSince1970: 0)
        history.record([reading(100, charging: true)], at: start)
        history.record([reading(99)], at: start + day)
        history.record([reading(99)], at: start + 2 * day)

        let mouse = try XCTUnwrap(history.mice.first)
        XCTAssertTrue(mouse.measured.isEmpty)
        XCTAssertNotNil(mouse.estimate)
        XCTAssertEqual(try XCTUnwrap(mouse.averageFullDays), 200, accuracy: 0.01, "1% in 2 days")
        XCTAssertEqual(try XCTUnwrap(mouse.current?.drainSoFar), 0.5, accuracy: 0.001)
    }

    func testChargingKeepsOneReadingAndItsTime() throws {
        var history = BatteryHistory()
        let start = Date(timeIntervalSince1970: 0)
        history.record([reading(50)], at: start - day)
        history.record([reading(40)], at: start)
        history.record([reading(40, charging: true)], at: start + 60)
        history.record([reading(70, charging: true)], at: start + 1_860)
        history.record([reading(100, charging: true)], at: start + 3_660)
        history.record([reading(100)], at: start + 3_720)
        history.record([reading(97)], at: start + day)

        let mouse = try XCTUnwrap(history.mice.first)
        let charging = mouse.readings.filter(\.isCharging)
        XCTAssertEqual(charging.count, 1, "Charging updates one reading")
        XCTAssertEqual(charging.first?.level, 100)
        XCTAssertEqual(charging.first?.date, start + 60)
        XCTAssertEqual(charging.first?.until, start + 3_660)

        let current = try XCTUnwrap(mouse.current)
        XCTAssertEqual(current.chargingTime, 3_600)
        XCTAssertEqual(current.start.date, start + 3_660, "The charge counts from when it stopped charging")
        XCTAssertEqual(current.used, 3)
        XCTAssertEqual(mouse.past.count, 1)
        XCTAssertNil(mouse.past.first?.chargingTime, "The log didn't see the first charge charging")
    }

    func testReadsTheOlderChargesShape() throws {
        let json = Data("""
        {"mice": [{"id": "mouse", "name": "Magic Mouse",
          "current": {"start": {"date": "2026-09-08T00:00:00Z", "level": 100}, "last": {"date": "2026-09-10T00:00:00Z", "level": 90}},
          "past": [{"start": {"date": "2026-08-01T00:00:00Z", "level": 100}, "last": {"date": "2026-09-07T00:00:00Z", "level": 8}}]}]}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let mouse = try XCTUnwrap(decoder.decode(BatteryHistory.self, from: json).mice.first)

        XCTAssertEqual(mouse.past.count, 1)
        XCTAssertEqual(mouse.past.first?.used, 92)
        XCTAssertEqual(mouse.current?.used, 10)
        XCTAssertEqual(try XCTUnwrap(mouse.current).days, 2, accuracy: 0.001)
        XCTAssertNil(mouse.current?.chargingTime)
    }

    func testDaysTextShowsItsTwoLargestUnits() {
        XCTAssertEqual(ChargeText.days(1.0 / 24), "1h")
        XCTAssertEqual(ChargeText.days(1), "1d")
        XCTAssertEqual(ChargeText.days(3.4), "3d 10h")
        XCTAssertEqual(ChargeText.days(55), "1mo 25d")
        XCTAssertEqual(ChargeText.days(60.2), "2mo")
        XCTAssertEqual(ChargeText.days(102), "3mo 12d")
    }

    func testDurationRollsHoursIntoDaysAndMonths() {
        XCTAssertEqual(ChargeText.duration(99 * 60), "1h 39m")
        XCTAssertEqual(ChargeText.duration((45 * 60 + 12) * 60), "1d 21h 12m")
        XCTAssertEqual(ChargeText.duration((90 * 60 + 3) * 60), "3d 18h 3m")
        XCTAssertEqual(ChargeText.duration(59.6 * 60), "1h")
        XCTAssertEqual(ChargeText.duration(((29 * 24 + 23) * 60 + 50) * 60, units: 2), "1mo")
    }

    func testEachDropIsAStepAndIdleOnesAreLeftOutOfInUse() throws {
        let hour: TimeInterval = 3_600
        let start = Date(timeIntervalSince1970: 0)
        var history = BatteryHistory()
        history.record([reading(100, charging: true)], at: start)
        history.record([reading(99)], at: start + 12 * hour)   // a night: idle
        history.record([reading(98)], at: start + 13 * hour)
        history.record([reading(99)], at: start + 13.5 * hour) // a wobble up
        history.record([reading(96)], at: start + 15 * hour)   // 2% in 2 hours
        history.record([reading(96)], at: start + 16 * hour)
        // As a file from before use was recorded: the steps fall back to guessing.
        for index in history.mice[0].readings.indices {
            history.mice[0].readings[index].inUseSeconds = nil
            history.mice[0].readings[index].idleSeconds = nil
        }

        let steps = try XCTUnwrap(history.mice.first?.current).steps
        XCTAssertEqual(steps.map(\.level), [99, 98, 96, 96])
        XCTAssertEqual(steps.map(\.isIdle), [true, false, false, false])
        XCTAssertEqual(steps[2].perPercent, hour, "The wobble doesn't restart the step")
        XCTAssertEqual(steps.last?.isOngoing, true)
        XCTAssertEqual(steps.last?.duration, hour)
        XCTAssertEqual(try XCTUnwrap(history.mice.first?.current?.inUsePerPercent), hour, accuracy: 0.001)
    }

    func testEachReadingCountsItsTimeInUseAndIdle() throws {
        let start = Date(timeIntervalSince1970: 0)
        var history = BatteryHistory()
        history.record([reading(100, charging: true)], at: start, state: .inUse)
        history.record([reading(100)], at: start + 60, state: .inUse)
        history.record([reading(100)], at: start + 120, state: .inUse)
        history.record([reading(100)], at: start + 180, state: .idle)
        // The Mac slept for an hour: one check of it can have been use.
        history.record([reading(99)], at: start + 3_780, state: .inUse)
        history.record([reading(99)], at: start + 3_840, state: .idle)

        let mouse = try XCTUnwrap(history.mice.first)
        let top = mouse.readings[1]
        XCTAssertEqual(top.inUseSeconds, 60 + 90)
        XCTAssertEqual(top.idleSeconds, 60 + 3_600 - 90)
        XCTAssertEqual(mouse.readings[2].state, .idle)
        XCTAssertEqual(mouse.readings[2].idleSeconds, 60)

        let steps = try XCTUnwrap(mouse.current).steps
        XCTAssertEqual(steps.first?.inUseSeconds, 150, "Measured, not guessed")
        XCTAssertEqual(steps.first?.isIdle, true, "Under half of it in use")
        XCTAssertEqual(steps.last?.inUseSeconds, 0)
    }

    func testAReadingFromBeforeTrackingStaysUnrecorded() {
        var old = BatteryReading(date: .now, level: 92, isCharging: false)
        old.count(60, state: .inUse)
        XCTAssertNil(old.inUseSeconds, "Its earlier time is unknown, so a minute isn't its total")
        XCTAssertEqual(old.state, .inUse)
    }

    func testEachDayCountsItsDropsAndSharesItsTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let midnight = Date(timeIntervalSince1970: 0)
        var history = BatteryHistory()
        history.record([reading(100, charging: true)], at: midnight + 22 * 3_600, state: .idle)
        history.record([reading(100)], at: midnight + 22 * 3_600 + 60, state: .idle)
        history.record([reading(99)], at: midnight + 26 * 3_600, state: .idle) // 4 idle hours across midnight
        history.record([reading(98)], at: midnight + 26 * 3_600 + 60, state: .inUse)

        let days = try XCTUnwrap(history.mice.first?.current).daily(calendar: calendar)
        XCTAssertEqual(days.map(\.used), [0, 2])
        XCTAssertEqual(days[0].idle, 2 * 3_600, accuracy: 1, "Two of the four hours fall before midnight")
        XCTAssertEqual(days[1].idle, 2 * 3_600, accuracy: 1)
        XCTAssertEqual(days[1].inUse, 60, accuracy: 1)
    }

    func testOlderReadingsWithoutUsageStillGuess() throws {
        let json = Data("""
        {"mice": [{"id": "mouse", "name": "Magic Mouse", "checkedAt": "2026-11-02T00:00:00Z", "readings": [
          {"date": "2026-11-01T00:00:00Z", "until": "2026-11-01T00:00:00Z", "level": 100, "isCharging": true},
          {"date": "2026-11-01T01:00:00Z", "level": 99, "isCharging": false},
          {"date": "2026-11-01T02:00:00Z", "level": 98, "isCharging": false}]}]}
        """.utf8)
        let mouse = try XCTUnwrap(decode(json).mice.first)
        let steps = try XCTUnwrap(mouse.current).steps
        XCTAssertNil(steps.first?.inUseSeconds)
        XCTAssertEqual(steps.first?.inUse, 3_600, "A quick 1% counts as use")
        XCTAssertEqual(steps.last?.isIdle, true, "22 hours for 1% is idle")
    }

    func testDropsOnlyTheEntriesItCantRead() throws {
        let json = Data("""
        {"version": 9, "mice": [
          {"name": "No id"},
          42,
          {"id": "mouse", "name": "Magic Mouse", "checkedAt": "2026-11-02T00:00:00Z", "readings": [
            {"date": "2026-11-01T02:00:00Z", "level": 98, "isCharging": false, "state": "in-use", "inUseSeconds": 60, "idleSeconds": 0},
            {"date": "2026-11-01T00:00:00Z", "until": "2026-11-01T00:00:00Z", "level": 100, "isCharging": true},
            {"date": "2026-11-01T01:00:00Z", "level": 500, "isCharging": false},
            {"date": "not a date", "level": 99, "isCharging": false},
            {"date": "2026-11-01T03:00:00Z", "level": 97, "isCharging": false, "state": "sleeping"},
            "junk"]}]}
        """.utf8)
        let history = try decode(json)
        XCTAssertEqual(history.mice.map(\.id), ["mouse"])
        XCTAssertEqual(history.mice.first?.readings.map(\.level), [100, 98], "Sorted, and the bad ones dropped")
    }

    func testWritesItsVersion() throws {
        let encoder = JSONEncoder()
        let object = try JSONSerialization.jsonObject(with: encoder.encode(BatteryHistory())) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, BatteryHistory.version)
    }

    private func decode(_ data: Data) throws -> BatteryHistory {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BatteryHistory.self, from: data)
    }

    func testLastChargedDateIsInTheUsersTimeZone() {
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(ChargeText.date(date), date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
        XCTAssertFalse(ChargeText.date(date).contains("Z"))
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
