import SwiftUI

/// One mouse's battery health: how long a full charge lasts, how fast it drains now, where the
/// charge it's on stands and how it has drained, each charge in a chart, and the list of them.
struct MouseHealthView: View {
    let mouse: MouseHistory
    /// When the drain report shows, the share of idle drain its tip waits for; nil hides it.
    var report: IdleTipThreshold?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        let current = mouse.current
        Divider()
        VStack(alignment: .leading, spacing: 24 * scale) {
            HStack {
                Label(mouse.name, systemImage: "computermouse.fill")
                    .appFont(.body, weight: .semibold)
                Spacer()
                if let trend = mouse.trend { TrendBadge(trend: trend) }
            }
            HStack(spacing: 10 * scale) {
                StatTile(value: mouse.averageFullDays.map { ChargeText.days($0) } ?? "—",
                         label: mouse.estimate == nil ? String(localized: "A full charge lasts")
                                                      : String(localized: "A full charge lasts, estimated so far"))
                StatTile(value: (current?.perDay ?? current?.drainSoFar).map { ChargeText.rate($0) } ?? "—",
                         label: String(localized: "Drain on this charge"))
            }
            .fixedSize(horizontal: false, vertical: true)
            if let current {
                HStack(spacing: 10 * scale) {
                    StatTile(value: ChargeText.date(current.start.date),
                             label: String(localized: "Last charged, \(ChargeText.days(current.days)) ago"))
                    StatTile(value: "\(current.last.level)%", label: String(localized: "Now"), level: current.last.level)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let current, current.used > 0 {
                DrainSteps(charge: current, showsPace: report == nil)
                DailyDrain(charge: current).featureSpot("clip-daily-drain")
            }
            if let report { DrainReportView(mouse: mouse, idleTip: report).featureSpot("clip-drain-report") }
            let measured = mouse.measured
            if measured.count >= 2 {
                ChargeChart(charges: measured, average: mouse.averageFullDays)
            } else {
                Text("A chart of every charge shows here once two have drained.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            let past = mouse.past
            if !past.isEmpty { ChargeTable(charges: past.reversed()) }
        }
    }
}
