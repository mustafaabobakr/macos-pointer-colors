import SwiftUI

/// Whether charges last shorter (red past 10%) or longer than when tracking began.
struct TrendBadge: View {
    let trend: Double

    var body: some View {
        let percent = Int((abs(trend) * 100).rounded())
        let worse = trend < -0.1
        Label(trend < 0 ? "\(percent)% shorter than at first" : "\(percent)% longer than at first",
              systemImage: trend < 0 ? "arrow.down.right" : "arrow.up.right")
            .appFont(.caption, weight: .semibold)
            .foregroundStyle(worse ? .red : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((worse ? Color.red : Color.secondary).opacity(0.15), in: Capsule())
    }
}
