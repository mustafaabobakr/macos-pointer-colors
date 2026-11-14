import SwiftUI

/// Marks a feature that's still being tuned: on its sidebar row and at the top of its page.
struct BetaBadge: View {
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Text("BETA")
            .appFont(.caption2, weight: .bold)
            .foregroundStyle(.orange)
            .padding(.horizontal, 6 * scale)
            .padding(.vertical, 2 * scale)
            .background(.orange.opacity(0.18), in: Capsule())
            .accessibilityLabel(Text("Beta"))
    }
}
