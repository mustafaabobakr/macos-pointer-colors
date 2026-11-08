import Charts
import SwiftUI

/// How the drain report moved, one point for each midnight it was worked out: the full charge, or
/// one of the three numbers it comes from, so a change can be traced to what caused it. Pointing
/// at a day tells all four.
struct EstimateHistory: View {
    let estimates: [DrainEstimate]
    @State private var metric = EstimateMetric.fullCharge
    @State private var selection: Date?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            header(selected: selection.flatMap(estimate(on:)))
            Picker("Shows", selection: $metric) {
                ForEach(EstimateMetric.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            chart
            Text(metric.explanation).appFont(.caption).foregroundStyle(.secondary)
        }
    }

    private var chart: some View {
        Chart(estimates, id: \.day) { estimate in
            LineMark(x: .value("Day", estimate.day, unit: .day), y: .value(metric.title, metric.value(estimate.report)))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Day", estimate.day, unit: .day), y: .value(metric.title, metric.value(estimate.report)))
                .symbolSize(30 * scale)
            if let selection, Calendar.current.isDate(estimate.day, inSameDayAs: selection) {
                RuleMark(x: .value("Day", estimate.day, unit: .day)).foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .foregroundStyle(Color.accentColor)
        .chartXSelection(value: $selection)
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel { Text(metric.axisText(value.as(Double.self) ?? 0)) }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true) }
        }
        .frame(height: 130 * scale)
    }

    private func estimate(on date: Date) -> DrainEstimate? {
        estimates.first { Calendar.current.isDate($0.day, inSameDayAs: date) }
    }

    private func header(selected: DrainEstimate?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("How the estimate moved").appFont(.caption, weight: .semibold)
            Spacer()
            if let selected { Text(Self.detail(of: selected)).appFont(.caption).monospacedDigit() }
        }
        .foregroundStyle(.secondary)
    }

    /// "Nov 6 · 22d 21h a charge · 1h 57m per 1% · 7h 36m use a day · 0.7% a day idle"
    static func detail(of estimate: DrainEstimate) -> String {
        let date = estimate.day.formatted(.dateTime.month(.abbreviated).day())
        let report = estimate.report
        let parts = [EstimateMetric.fullCharge, .inUsePerPercent, .usePerDay, .idlePerDay].map { $0.text(report) }
        return String(localized: "\(date) · \(parts[0]) a charge · \(parts[1]) per 1% · \(parts[2]) use a day · \(parts[3]) idle")
    }
}
