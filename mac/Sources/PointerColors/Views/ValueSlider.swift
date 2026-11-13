import SwiftUI

/// A setting with a slider and its value, formatted, at the end of the row. With `ends`, a symbol
/// at each end of the slider says what moving it does, and pressing it steps the value that way
/// (see `StepSlider`); a time runs from slow on the left to fast on the right, as macOS draws speed.
struct ValueSlider: View {
    let title: String
    let symbol: String
    var caption: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    /// Marks the slider itself, not its row, for a clip that drags it.
    var spot: String?
    /// Multiplies the value for its label, as 100 to show a 0–1 value as a percentage.
    var scale = 1.0
    /// Snaps the value to this step, and is what one press on an end moves; nil slides freely and
    /// a press moves the smallest change the label shows.
    var step: Double?
    var ends: SliderEnds?

    var body: some View {
        SettingsRow(symbol: symbol, title: Text(title), caption: caption.map { Text($0) }) {
            StepSlider(value: $value, range: range, step: step,
                       nudge: SliderNudge.amount(step: step, format: format, scale: scale, range: range),
                       icons: ends?.icons, title: Text(title), valueText: valueText, spot: spot)
                .frame(width: ends == nil ? 220 : 264)
            Text(valueText).monospacedDigit().foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }

    private var valueText: String { String(format: format, value * scale) }
}
