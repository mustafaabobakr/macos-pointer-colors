import Foundation

/// A charge's dates, length and drain in words.
enum ChargeText {
    static func dates(_ charge: Charge) -> String {
        (charge.start.date..<max(charge.last.date, charge.start.date)).formatted(.interval.month(.abbreviated).day())
    }

    static func days(_ days: Double) -> String {
        days < 1 ? String(localized: "\(Int((days * 24).rounded())) hours")
                 : String(localized: "\(Int(days.rounded())) days")
    }

    static func rate(_ perDay: Double) -> String {
        String(localized: "\(perDay.formatted(.number.precision(.fractionLength(1))))% a day")
    }
}
