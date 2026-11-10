import Foundation

/// The drain report as it stood at one midnight, so the chart can show how it moved and why.
struct DrainEstimate: Equatable {
    /// The midnight it was worked out at, starting the day it was shown.
    let day: Date
    let report: DrainReport

    /// Days of estimates the chart goes back, unless set otherwise.
    static let historyDays = 60
}

extension MouseHistory {
    /// The report at each midnight it could be worked out, oldest first, over the last `days`
    /// days up to today's, each with the use a day from the `useDays` days before it.
    func drainEstimates(days: Int = DrainEstimate.historyDays, useDays: Int = DrainReport.useDays,
                        calendar: Calendar = .current, now: Date = .now) -> [DrainEstimate] {
        let today = calendar.startOfDay(for: now)
        return (0...days).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today),
                  let report = drainReport(asOf: day, useDays: useDays, calendar: calendar) else { return nil }
            return DrainEstimate(day: day, report: report)
        }
    }
}
