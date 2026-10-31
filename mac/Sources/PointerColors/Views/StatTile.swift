import SwiftUI

/// A number large, with what it means under it; with `level`, a battery bar too.
struct StatTile: View {
    let value: String
    let label: String
    var level: Int?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        VStack(alignment: .leading, spacing: 4 * scale) {
            Text(value)
                .appFont(.title2, weight: .semibold)
                .monospacedDigit()
            if let level {
                ProgressView(value: Double(level), total: 100)
                    .tint(level < 20 ? .red : .green)
            }
            Text(label)
                .appFont(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12 * scale)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
