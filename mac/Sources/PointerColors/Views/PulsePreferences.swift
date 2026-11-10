import SwiftUI

/// Preferences › Pulse: a ring that grows and fades where you click.
struct PulsePreferences: View {
    @Bindable var highlight: PointerHighlight
    let pair: PointerPair
    let pointerScale: Double

    var body: some View {
        SettingsPage("Pulse") {
            SettingsCard(anchor: "highlight.pulse") {
                HighlightPreviewBanner(scene: .pulse, pair: pair, sample: sample, isOn: highlight.pulseOn)
                SettingsToggle("Show a pulse on each click", symbol: "circle.circle",
                               caption: "A ring that grows and fades where you click.", isOn: $highlight.pulseOn)
                PulseRows(highlight: highlight)
                    .disabled(!highlight.pulseOn)
            }
            .featureSpot("pulse")
        }
    }

    /// The pulses alone, without the ring around the pointer.
    private var sample: HighlightPreviewSample {
        var style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        style.showsRing = false
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale)
    }
}

/// Everything that shapes a pulse, under its switch.
private struct PulseRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor)
        SettingsRow("Style", symbol: "circle.circle") {
            Picker("Style", selection: $highlight.pulseStyle) {
                ForEach(PulseStyle.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .featureSpot("clip-pulse-style")
        SettingsToggle("Dark outline", symbol: "circle.dashed.inset.filled",
                       caption: "Draws each pulse over the pair's dark color, as the laser's outline, so it stays clear on light backgrounds.",
                       isOn: $highlight.pulseOutlined)
        ValueSlider(title: String(localized: "Outline width"), symbol: "lineweight", value: $highlight.pulseOutlineWidth,
                    range: PointerHighlight.pulseOutlineWidthRange, format: "%.1f pt")
            .disabled(!highlight.pulseOutlined)
        ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.pulseSize,
                    range: PointerHighlight.sizeRange, format: "%.1f×", spot: "clip-pulse-size")
        ValueSlider(title: String(localized: "Length"), symbol: "timer", value: $highlight.pulseDuration,
                    range: PointerHighlight.pulseDurationRange, format: "%.2f s")
        SettingsToggle("Pulse on right-clicks too", symbol: "cursorarrow.click", isOn: $highlight.pulsesOnRightClick)
        SettingsToggle("Show long presses", symbol: "hand.tap",
                       caption: "Holding the button keeps a small filled ring under the pointer, and letting go sends out a pulse, so a press looks different from a click.",
                       isOn: $highlight.pulseShowsHold)
            .featureSpot("clip-pulse-hold")
    }
}
