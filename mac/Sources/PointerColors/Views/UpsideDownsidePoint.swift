import SwiftUI

/// One upside or downside, marked with a plus or a minus.
struct UpsideDownsidePoint: View {
    let text: String
    let isUpside: Bool
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4 * scale) {
            Image(systemName: isUpside ? "plus.circle.fill" : "minus.circle.fill")
                .foregroundStyle(isUpside ? .green : .orange)
                .accessibilityLabel(isUpside ? Text("Upside") : Text("Downside"))
            Text(text).appFont(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appFont(.caption)
    }
}
