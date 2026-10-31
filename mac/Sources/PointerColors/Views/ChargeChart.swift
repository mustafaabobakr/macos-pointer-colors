import Charts
import SwiftUI

/// How many days each charge would last from full, oldest to newest, against the average.
struct ChargeChart: View {
    let charges: [Charge]
    let average: Double?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scale) {
            HStack {
                Text("Days a full charge lasts, charge by charge")
                    .appFont(.caption, weight: .semibold)
                Spacer()
                if let average { Text("- - average \(ChargeText.days(average))").appFont(.caption) }
            }
            .foregroundStyle(.secondary)
            Chart {
                ForEach(Array(charges.enumerated()), id: \.offset) { index, charge in
                    BarMark(x: .value("Charge", "\(index + 1)"), y: .value("Days", Charge.fullDays(of: [charge]) ?? 0))
                        .foregroundStyle(index == charges.count - 1 ? Color.accentColor.opacity(0.45) : Color.accentColor)
                        .cornerRadius(3)
                }
                if let average {
                    RuleMark(y: .value("Average", average))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 120 * scale)
        }
    }
}
