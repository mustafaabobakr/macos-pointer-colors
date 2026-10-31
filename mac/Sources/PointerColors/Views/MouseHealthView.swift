import SwiftUI

/// One mouse's battery health: how long a full charge lasts, how fast it drains now, where the
/// charge it's on stands, each charge in a chart, and the list of them.
struct MouseHealthView: View {
    let mouse: MouseHistory
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 14 * scale) {
            HStack {
                Label(mouse.name, systemImage: "computermouse.fill")
                    .appFont(.body, weight: .semibold)
                Spacer()
                if let trend = mouse.trend { TrendBadge(trend: trend) }
            }
            HStack(spacing: 10 * scale) {
                StatTile(value: mouse.averageFullDays.map { ChargeText.days($0) } ?? "—",
                         label: String(localized: "A full charge lasts"))
                StatTile(value: mouse.current.perDay.map { ChargeText.rate($0) } ?? "—",
                         label: String(localized: "Drain on this charge"))
                StatTile(value: "\(mouse.current.last.level)%", label: currentLabel,
                         level: mouse.current.last.level)
            }
            .fixedSize(horizontal: false, vertical: true)
            if mouse.measured.count >= 2 {
                ChargeChart(charges: mouse.measured, average: mouse.averageFullDays)
            } else {
                Text("A chart of every charge shows here once two have drained.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            if !mouse.past.isEmpty { ChargeTable(charges: mouse.past.reversed()) }
        }
    }

    private var currentLabel: String {
        String(localized: "Now, after \(ChargeText.days(mouse.current.days))")
    }
}
