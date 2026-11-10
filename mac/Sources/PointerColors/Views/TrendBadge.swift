import SwiftUI

/// Whether charges last shorter (red past the wear tip's share) or longer than when tracking began.
struct TrendBadge: View {
    let trend: Double
    /// How much shorter turns it red, 0 to 1: the wear tip's setting.
    let wearShare: Double

    var body: some View {
        let percent = Int((abs(trend) * 100).rounded())
        let worse = trend < -wearShare
        Label(trend < 0 ? "\(percent)% shorter than at first" : "\(percent)% longer than at first",
              systemImage: trend < 0 ? "arrow.down.right" : "arrow.up.right")
            .appFont(.caption, weight: .semibold)
            .foregroundStyle(worse ? .red : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((worse ? Color.red : Color.secondary).opacity(0.15), in: Capsule())
    }
}
