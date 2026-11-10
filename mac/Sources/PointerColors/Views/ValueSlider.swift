import SwiftUI

/// A setting with a slider and its value, formatted, at the end of the row.
struct ValueSlider: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    /// Marks the slider itself, not its row, for a clip that drags it.
    var spot: String?
    /// Multiplies the value for its label, as 100 to show a 0–1 value as a percentage.
    var scale = 1.0
    /// Snaps the value to this step; nil slides freely.
    var step: Double?

    var body: some View {
        SettingsRow(symbol: symbol, title: Text(title)) {
            slider.accessibilityLabel(title).featureSpot(spot ?? "")
                .frame(width: 220)
            Text(String(format: format, value * scale)).monospacedDigit().foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: $value, in: range, step: step)
        } else {
            Slider(value: $value, in: range)
        }
    }
}
