import XCTest
@testable import PointerColors

final class DrainReportTests: XCTestCase {
    /// A 1% drop with these hours in use and idle.
    private func step(_ use: Double, _ idle: Double, at hour: Double) -> DrainStep {
        let start = Date(timeIntervalSince1970: hour * 3_600)
        return DrainStep(from: 50, level: 49, start: start, end: start + (use + idle) * 3_600,
                         isOngoing: false, inUseSeconds: use * 3_600)
    }

    /// Drops that drain exactly 0.35% an hour in use and 0.03% an hour idle.
    private func steps(_ uses: [Double]) -> [DrainStep] {
        uses.enumerated().map { index, use in step(use, (1 - 0.35 * use) / 0.03, at: Double(index) * 40) }
    }

    func testFindsTheInUseAndIdleRates() throws {
        let report = try XCTUnwrap(DrainReport(steps: steps([0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8, 2.2])))
        XCTAssertEqual(report.inUsePerHour, 0.35, accuracy: 0.0001)
        XCTAssertEqual(report.idlePerHour, 0.03, accuracy: 0.0001)
        XCTAssertEqual(report.idlePerDay, 0.72, accuracy: 0.001)
        XCTAssertEqual(report.totalInUse, 16.3 * 3_600, accuracy: 0.01)
        XCTAssertEqual(report.totalInUse / (report.totalInUse + report.totalIdle) * 24, report.useHoursPerDay, accuracy: 0.0001)
        XCTAssertEqual(report.perDay, 0.35 * report.useHoursPerDay + 0.03 * (24 - report.useHoursPerDay), accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(report.fullChargeDays), 100 / report.perDay, accuracy: 0.0001)
    }

    func testRatesAddUpToEveryPercentThatDrained() throws {
        // Noisy drops: the scaled rates still explain all 10% over the hours they took.
        let uses: [Double] = [0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8, 2.2]
        let drops = uses.enumerated().map { index, use in step(use, (1 - 0.35 * use) / 0.03 * (index % 2 == 0 ? 1.4 : 0.7), at: Double(index) * 60) }
        let report = try XCTUnwrap(DrainReport(steps: drops))
        let explained = drops.reduce(0) { $0 + report.inUsePerHour * $1.inUse / 3_600 + report.idlePerHour * $1.idle / 3_600 }
        XCTAssertEqual(explained, 10, accuracy: 0.0001)
    }

    func testWaitsForTenMeasuredDrops() {
        XCTAssertNil(DrainReport(steps: steps([0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8])))
        var unmeasured = steps([0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8])
        unmeasured.append(DrainStep(from: 50, level: 49, start: .now, end: .now + 3_600, isOngoing: false))
        XCTAssertNil(DrainReport(steps: unmeasured), "A drop from before use was recorded doesn't count")
        XCTAssertEqual(DrainReport.measured(unmeasured).count, 9)
    }

    func testTakesANegativeIdleRateAsNone() throws {
        // Long idle stretches that drained less than the use alone explains.
        let drops = (0..<10).map { step(2.5, Double($0 % 2 == 0 ? 20 : 1), at: Double($0) * 40) }
        let report = try XCTUnwrap(DrainReport(steps: drops))
        XCTAssertEqual(report.idlePerHour, 0)
        XCTAssertEqual(report.inUsePerHour, 0.4, accuracy: 0.0001)
    }

    func testSuggestsTurningItOffAndFlagsWear() throws {
        let report = try XCTUnwrap(DrainReport(steps: steps([0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8, 2.2])))
        XCTAssertEqual(report.tips(idleShare: 0.99, trend: nil, wearShare: 0.15), [])
        XCTAssertEqual(report.tips(idleShare: 0.01, trend: -0.2, wearShare: 0.15), [.idle(share: report.idleShare), .wear(trend: -0.2)])
        XCTAssertEqual(report.tips(idleShare: 0.99, trend: -0.1, wearShare: 0.15), [], "A 10% shorter charge is within noise")
    }

    func testWearTipFollowsItsSetting() throws {
        let report = try XCTUnwrap(DrainReport(steps: steps([0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8, 2.2])))
        XCTAssertEqual(report.tips(idleShare: 0.99, trend: -0.2, wearShare: 0.25), [])
        XCTAssertEqual(report.tips(idleShare: 0.99, trend: -0.06, wearShare: 0.05), [.wear(trend: -0.06)])
    }

    func testTakesTheUseADayItIsGiven() throws {
        let drops = steps([0.5, 1, 1.5, 2, 2.5, 2.8, 0.8, 1.2, 1.8, 2.2])
        let report = try XCTUnwrap(DrainReport(steps: drops, useHoursPerDay: 6))
        XCTAssertEqual(report.useHoursPerDay, 6)
        XCTAssertEqual(report.inUsePerHour, try XCTUnwrap(DrainReport(steps: drops)).inUsePerHour)
    }

    /// Three days, checked each minute, that drain 1% every 2 hours, in use from 8:00 to 16:00.
    private func threeDays() -> MouseHistory {
        let start = Date(timeIntervalSince1970: 0)
        var mouse = MouseHistory(id: "mouse", name: "Mouse", checkedAt: start)
        mouse.record(level: 100, charging: true, at: start)
        for minute in 1...(72 * 60) {
            let state: UsageState = (8..<16).contains((minute - 1) / 60 % 24) ? .inUse : .idle
            mouse.record(level: 100 - minute / 120, charging: false, at: start + Double(minute) * 60, state: state)
        }
        return mouse
    }

    func testWorksTheReportOutAtMidnightFromTheLastWeeksUse() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let mouse = threeDays()
        let midnight = Date(timeIntervalSince1970: 2 * 86_400)
        let report = try XCTUnwrap(mouse.drainReport(asOf: midnight, calendar: calendar))
        XCTAssertEqual(report.steps, DrainReport.measured(mouse.allSteps.filter { $0.end <= midnight }).count)
        XCTAssertLessThan(report.steps, DrainReport.measured(mouse.allSteps).count, "Drops after midnight wait for the next one")
        XCTAssertEqual(report.useHoursPerDay, 8, accuracy: 0.5)

        let estimates = mouse.drainEstimates(calendar: calendar, now: midnight + 3_600)
        XCTAssertEqual(estimates.map(\.day), [midnight - 86_400, midnight])
        XCTAssertEqual(estimates.last?.report, report)
    }

    func testChartRangeAndDaysCountedAreTheirSettings() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let mouse = threeDays()
        let midnight = Date(timeIntervalSince1970: 2 * 86_400)
        let estimates = mouse.drainEstimates(days: 0, useDays: 1, calendar: calendar, now: midnight + 3_600)
        XCTAssertEqual(estimates.map(\.day), [midnight], "Only as far back as the chart's range")
        XCTAssertEqual(try XCTUnwrap(mouse.useHoursPerDay(before: midnight, days: 1, calendar: calendar)), 8, accuracy: 0.5)
        XCTAssertNil(mouse.useHoursPerDay(before: midnight - 2 * 86_400, days: 3, calendar: calendar), "No use recorded before it")
    }

    func testIdleThresholdsReadPlainly() {
        XCTAssertEqual(IdleTipThreshold.allCases.map(\.share), [0.15, 0.25, 0.40])
        XCTAssertEqual(IdleTipThreshold.above25.title, "Over 25% of the drain")
    }
}
