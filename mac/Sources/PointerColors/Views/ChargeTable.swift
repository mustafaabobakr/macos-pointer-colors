import SwiftUI

/// Past charges, newest first, one row each: when, how long, how far it drained, how fast, and
/// how long it took to charge.
struct ChargeTable: View {
    let charges: [Charge]

    var body: some View {
        DisclosureGroup("Past charges (\(charges.count))") {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Dates"); Text("Lasted"); Text("Used"); Text("A day"); Text("Charged in")
                }
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                ForEach(Array(charges.enumerated()), id: \.offset) { _, charge in
                    GridRow {
                        Text(ChargeText.dates(charge))
                        Text(ChargeText.days(charge.days))
                        Text("\(charge.start.level)% → \(charge.last.level)%")
                        Text(charge.perDay.map { ChargeText.rate($0) } ?? "—")
                        Text(charge.chargingTime.map { ChargeText.duration($0) } ?? "—")
                    }
                    .appFont(.caption)
                    .monospacedDigit()
                }
            }
            .padding(.top, 6)
        }
    }
}
