import SwiftUI

/// Past charges, newest first, one row each: when, how long, how far it drained, and how fast.
struct ChargeTable: View {
    let charges: [Charge]

    var body: some View {
        DisclosureGroup("Past charges (\(charges.count))") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Dates"); Text("Lasted"); Text("Used"); Text("A day")
                }
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                ForEach(Array(charges.enumerated()), id: \.offset) { _, charge in
                    GridRow {
                        Text(ChargeText.dates(charge))
                        Text(ChargeText.days(charge.days))
                        Text("\(charge.start.level)% → \(charge.last.level)%")
                        Text(charge.perDay.map { ChargeText.rate($0) } ?? "—")
                    }
                    .appFont(.caption)
                    .monospacedDigit()
                }
            }
            .padding(.top, 6)
        }
    }
}
