import SwiftUI

/// A slider with an optional symbol at each end. Pressing a symbol moves the value one `nudge`
/// toward that end, and holding it keeps going. Every slider in the app is one of these, alone or
/// inside a `ValueSlider` row.
struct StepSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    /// Snaps the value to this step while dragging; nil slides freely.
    var step: Double?
    /// How far one press on an end symbol moves the value.
    let nudge: Double
    var icons: SliderIcons?
    /// For VoiceOver: what the slider sets, and its value as the row shows it.
    let title: Text
    var valueText: String?
    /// Marks the slider itself, not its ends, for a clip that drags it.
    var spot: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icons { NudgeButton(end: icons.low) { press(towardHigh: false, icons: icons) } }
            slider
                .accessibilityLabel(title)
                .accessibilityValue(valueText ?? "")
                .featureSpot(spot ?? "")
            if let icons { NudgeButton(end: icons.high) { press(towardHigh: true, icons: icons) } }
        }
    }

    /// Moves the knob toward the pressed end: for a reversed slider that's the other way in value.
    private func press(towardHigh: Bool, icons: SliderIcons) {
        let grows = towardHigh != icons.isReversed
        value = SliderNudge.nudged(value, by: grows ? nudge : -nudge, in: range)
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: position, in: range, step: step)
        } else {
            Slider(value: position, in: range)
        }
    }

    /// Where the knob sits: the value, or for a reversed slider its mirror, so the largest is on the left.
    private var position: Binding<Double> {
        guard icons?.isReversed == true else { return $value }
        let (low, high) = (range.lowerBound, range.upperBound)
        return Binding(get: { high + low - value }, set: { value = high + low - $0 })
    }
}
