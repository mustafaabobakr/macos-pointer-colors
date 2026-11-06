import Charts
import SwiftUI

/// Each day of the charge as a bar of its hours, in use below and idle above, with how much of the
/// battery the day took written on top. Pointing at a day tells its numbers.
struct DailyDrain: View {
    let charge: Charge
    @State private var selection: Date?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        let days = charge.daily()
        VStack(alignment: .leading, spacing: 12 * scale) {
            header(selected: selection.flatMap { date in days.first { Calendar.current.isDate($0.day, inSameDayAs: date) } })
            Chart(days, id: \.day) { day in
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Hours", day.inUse / 3_600), width: .ratio(0.6))
                    .foregroundStyle(UsageColors.inUse)
                BarMark(x: .value("Day", day.day, unit: .day), y: .value("Hours", day.idle / 3_600), width: .ratio(0.6))
                    .foregroundStyle(UsageColors.idle)
                    .annotation(position: .top, spacing: 3) {
                        if day.used > 0 {
                            Text("−\(day.used)%").font(.system(size: 10 * scale, weight: .medium)).monospacedDigit()
                        }
                    }
            }
            .chartXSelection(value: $selection)
            .chartYScale(domain: 0...24)
            .chartYAxis {
                AxisMarks(values: [0, 12, 24]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)h") }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) }
            }
            .frame(height: 150 * scale)
        }
    }

    private func header(selected: DrainDay?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Used each day").appFont(.caption, weight: .semibold)
            Spacer()
            if let selected { Text(Self.detail(of: selected)).appFont(.caption).monospacedDigit() } else { UsageLegend() }
        }
        .foregroundStyle(.secondary)
    }

    /// "Nov 2 · used 5% · 2h 10m in use · 16h 4m idle"
    static func detail(of day: DrainDay) -> String {
        let date = day.day.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "\(date) · used \(day.used)% · \(ChargeText.duration(day.inUse)) in use · \(ChargeText.duration(day.idle)) idle")
    }
}
