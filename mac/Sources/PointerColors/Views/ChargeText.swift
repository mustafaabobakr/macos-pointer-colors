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

    /// Hours under a day, days under a month, then months and days, like "1 month, 25 days".
    static func days(_ days: Double) -> String {
        guard days < 30 else { return months(Int(days.rounded())) }
        let unit: Duration.UnitsFormatStyle.Unit = days < 1 ? .hours : .days
        return Duration.seconds(days * 86_400).formatted(.units(allowed: [unit], width: .wide, maximumUnitCount: 1))
    }

    /// A month counts as 30 days.
    private static func months(_ days: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.month, .day]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: DateComponents(month: days / 30, day: days % 30)) ?? "\(days)"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .narrow, maximumUnitCount: 2))
    }

    static func rate(_ perDay: Double) -> String {
        String(localized: "\(perDay.formatted(.number.precision(.fractionLength(1))))% a day")
    }
}
