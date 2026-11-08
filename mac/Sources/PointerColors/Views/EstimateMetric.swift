import Foundation

/// One number of the drain report the estimate chart can follow: the full charge, or one of the
/// three things it's worked out from.
enum EstimateMetric: String, CaseIterable, Identifiable {
    case fullCharge, inUsePerPercent, usePerDay, idlePerDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullCharge: String(localized: "Full charge")
        case .inUsePerPercent: String(localized: "In use per 1%")
        case .usePerDay: String(localized: "Use a day")
        case .idlePerDay: String(localized: "Idle a day")
        }
    }

    /// What it means for the full charge, said under the chart.
    var explanation: String {
        switch self {
        case .fullCharge: String(localized: "How long a full charge lasts, as worked out each midnight from the three below.")
        case .inUsePerPercent: String(localized: "How long 1% lasts in use. Higher means a charge lasts longer.")
        case .usePerDay: String(localized: "Hours in use a day, over the last 7 days. More use means a charge lasts less.")
        case .idlePerDay: String(localized: "What a whole day idle takes. More idle drain means a charge lasts less.")
        }
    }

    /// The value as the chart plots it: days, minutes, hours, or percent.
    func value(_ report: DrainReport) -> Double {
        switch self {
        case .fullCharge: report.fullChargeDays ?? 0
        case .inUsePerPercent: 60 / report.inUsePerHour
        case .usePerDay: report.useHoursPerDay
        case .idlePerDay: report.idlePerDay
        }
    }

    /// The value in words, like "18d 19h" or "0.7% a day".
    func text(_ report: DrainReport) -> String {
        switch self {
        case .fullCharge: report.fullChargeDays.map { ChargeText.days($0) } ?? "—"
        case .inUsePerPercent: ChargeText.duration(3_600 / report.inUsePerHour)
        case .usePerDay: ChargeText.duration(report.useHoursPerDay * 3_600)
        case .idlePerDay: ChargeText.rate(report.idlePerDay)
        }
    }

    /// An axis label for a plotted value.
    func axisText(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        switch self {
        case .fullCharge: return String(localized: "\(number)d")
        case .inUsePerPercent: return String(localized: "\(number)m")
        case .usePerDay: return String(localized: "\(number)h")
        case .idlePerDay: return "\(number)%"
        }
    }
}
