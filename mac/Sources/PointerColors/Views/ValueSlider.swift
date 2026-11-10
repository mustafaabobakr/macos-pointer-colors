import SwiftUI

/// A setting with a slider and its value, formatted, at the end of the row. With `ends`, a symbol
/// at each end of the slider says what moving it does; a time runs from slow on the left to fast
/// on the right, as macOS draws speed.
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
    var ends: SliderEnds?

    var body: some View {
        SettingsRow(symbol: symbol, title: Text(title)) {
            HStack(spacing: 6) {
                if let ends { ends.low.image }
                slider.accessibilityLabel(title).accessibilityValue(valueText).featureSpot(spot ?? "")
                if let ends { ends.high.image }
            }
            .frame(width: ends == nil ? 220 : 264)
            Text(valueText).monospacedDigit().foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private var valueText: String { String(format: format, value * scale) }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: position, in: range, step: step)
        } else {
            Slider(value: position, in: range)
        }
    }

    /// Where the knob sits: the value, or for a time its mirror, so the longest time is on the left.
    private var position: Binding<Double> {
        guard ends?.isReversed == true else { return $value }
        let (low, high) = (range.lowerBound, range.upperBound)
        return Binding(get: { high + low - value }, set: { value = high + low - $0 })
    }
}
