import SwiftUI

/// The battery level in a small capsule, as the label under the pointer draws it, and as its
/// preview in Preferences shows it.
struct BatteryLabelView: View {
    let level: Int
    let charging: Bool
    /// Below this the level is red, unless it's charging.
    let redLevel: Int

    var body: some View {
        Label("\(level)%", systemImage: symbol)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(level < redLevel && !charging ? .red : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .padding(2)
    }

    private var symbol: String {
        if charging { return "battery.100percent.bolt" }
        return switch level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}
