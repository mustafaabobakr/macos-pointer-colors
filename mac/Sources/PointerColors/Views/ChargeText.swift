import Foundation

/// A charge's dates, length and drain in words.
enum ChargeText {
    static func dates(_ charge: Charge) -> String {
        (charge.start.date..<max(charge.last.date, charge.start.date)).formatted(.interval.month(.abbreviated).day())
    }

    /// A day and time in the user's time zone and locale, like "Oct 31, 8:00 PM".
    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// A number of days in its two largest units, like "18d 19h" or "1mo 5d".
    static func days(_ days: Double) -> String {
        duration(days * 86_400, units: 2)
    }

    /// A length of time in its largest `units` units, from months down to minutes, like
    /// "1d 21h 12m" or "3d 18h 3m". It's rounded to the smallest unit shown, and a month counts
    /// as 30 days.
    static func duration(_ seconds: TimeInterval, units count: Int = 3) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        let step = units[min(largestUnit(minutes) + count, units.count) - 1].minutes
        var left = Int((Double(minutes) / Double(step)).rounded()) * step
        let shown = units[largestUnit(left)...].prefix(count)
        var parts = DateComponents()
        for unit in shown {
            parts.setValue(left / unit.minutes, for: unit.component)
            left %= unit.minutes
        }
        return formatter().string(from: parts) ?? ""
    }

    /// Months (of 30 days), days, hours and minutes, each in minutes.
    private static let units: [(component: Calendar.Component, minutes: Int)] =
        [(.month, 43_200), (.day, 1_440), (.hour, 60), (.minute, 1)]

    /// Where in `units` the first one that `minutes` fills is; minutes when none is.
    private static func largestUnit(_ minutes: Int) -> Int {
        units.firstIndex { minutes >= $0.minutes } ?? units.count - 1
    }

    private static func formatter() -> DateComponentsFormatter {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.month, .day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter
    }

    static func rate(_ perDay: Double) -> String {
        String(localized: "\(perDay.formatted(.number.precision(.fractionLength(1))))% a day")
    }
}
