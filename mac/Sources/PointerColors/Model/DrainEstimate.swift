import Foundation

/// The drain report as it stood at one midnight, so the chart can show how it moved and why.
struct DrainEstimate: Equatable {
    /// The midnight it was worked out at, starting the day it was shown.
    let day: Date
    let report: DrainReport

    /// Days of estimates the chart goes back.
    static let historyDays = 60
}

extension MouseHistory {
    /// The report at each midnight it could be worked out, oldest first, over the last
    /// `DrainEstimate.historyDays` days up to today's.
    func drainEstimates(calendar: Calendar = .current, now: Date = .now) -> [DrainEstimate] {
        let today = calendar.startOfDay(for: now)
        return (0...DrainEstimate.historyDays).reversed().compactMap { back in
            guard let day = calendar.date(byAdding: .day, value: -back, to: today),
                  let report = drainReport(asOf: day, calendar: calendar) else { return nil }
            return DrainEstimate(day: day, report: report)
        }
    }
}
