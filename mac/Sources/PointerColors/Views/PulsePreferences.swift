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
                               caption: "A ring that grows and fades where you click. The picture shows it at its real size.",
                               isOn: $highlight.pulseOn.revealing())
                Reveal(isShown: highlight.pulseOn) { PulseRows(highlight: highlight) }
            }
            .featureSpot("pulse")
            Reveal(isShown: highlight.pulseOn) {
                SettingsCard("Long presses", anchor: "highlight.hold") {
                    HoldRows(highlight: highlight)
                }
            }
        }
    }

    /// The pulses alone, without the ring around the pointer, as large as they show on screen.
    private var sample: HighlightPreviewSample {
        var style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        style.showsRing = false
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale, realSize: true)
    }
}

/// Everything that shapes a pulse, under its switch: what both styles share first, then the
/// style, then the rows that change with it.
private struct PulseRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor)
        SharedPulseRows(highlight: highlight)
        SettingsRow("Style", symbol: "circle.circle") {
            Picker("Style", selection: $highlight.pulseStyle.revealing()) {
                ForEach(PulseStyle.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
        }
        .featureSpot("clip-pulse-style")
        Reveal(isShown: highlight.pulseStyle == .ring) { RingStyleRows(highlight: highlight) }
        Reveal(isShown: highlight.pulseStyle == .ripple) { RippleStyleRows(highlight: highlight) }
    }
}

/// Outline, size, length and right-clicks, the same for the Ring and Ripple styles.
private struct SharedPulseRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle("Dark outline", symbol: "circle.dashed.inset.filled",
                       caption: "Draws each pulse over the pair's dark color, as the laser's outline, so it stays clear on light backgrounds.",
                       isOn: $highlight.pulseOutlined.revealing())
        Reveal(isShown: highlight.pulseOutlined) {
            ValueSlider(title: String(localized: "Outline width"), symbol: "lineweight", value: $highlight.pulseOutlineWidth,
                        range: PointerHighlight.pulseOutlineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
        }
        ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.pulseSize,
                    range: PointerHighlight.sizeRange, format: "%.1f×", spot: "clip-pulse-size", ends: .size)
        ValueSlider(title: String(localized: "Length"), symbol: "timer", value: $highlight.pulseDuration,
                    range: PointerHighlight.pulseDurationRange, format: "%.2f s", ends: .time)
        SettingsToggle("Pulse on right-clicks too", symbol: "cursorarrow.click", isOn: $highlight.pulsesOnRightClick)
    }
}

/// The Ring style: one ring.
private struct RingStyleRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.pulseLineWidth,
                    range: PointerHighlight.lineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
        ValueSlider(title: String(localized: "Grows to"), symbol: "arrow.up.left.and.arrow.down.right.circle",
                    value: $highlight.pulseGrowth, range: PointerHighlight.growthRange, format: "%.1f×", step: 0.2, ends: .size)
        ValueSlider(title: String(localized: "Starting opacity"), symbol: "circle.lefthalf.filled", value: $highlight.pulseOpacity,
                    range: PointerHighlight.opacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
    }
}

/// The Ripple style: several thinner waves, one after another.
private struct RippleStyleRows: View {
    @Bindable var highlight: PointerHighlight

    private var waves: Binding<Double> {
        Binding(get: { Double(highlight.rippleWaves) }, set: { highlight.rippleWaves = Int($0.rounded()) })
    }

    var body: some View {
        let range = PointerHighlight.rippleWavesRange
        ValueSlider(title: String(localized: "Waves"), symbol: "dot.radiowaves.right", value: waves,
                    range: Double(range.lowerBound)...Double(range.upperBound), format: "%.0f", step: 1, ends: .count)
        ValueSlider(title: String(localized: "Grows to"), symbol: "arrow.up.left.and.arrow.down.right.circle",
                    value: $highlight.rippleGrowth, range: PointerHighlight.growthRange, format: "%.1f×", step: 0.2, ends: .size)
        ValueSlider(title: String(localized: "Gap between waves"), symbol: "arrow.left.and.right", value: $highlight.rippleSpacing,
                    range: PointerHighlight.rippleSpacingRange, format: "%.0f%%", scale: 100, step: 0.01, ends: .spread)
        ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.rippleLineWidth,
                    range: PointerHighlight.rippleLineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
        ValueSlider(title: String(localized: "Starting opacity"), symbol: "circle.lefthalf.filled", value: $highlight.rippleOpacity,
                    range: PointerHighlight.opacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
    }
}

/// The ring a long press keeps under the pointer, under its own switch.
private struct HoldRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle("Show long presses", symbol: "hand.tap",
                       caption: "Holding the button keeps a small filled ring under the pointer, and letting go sends out a pulse, so a press looks different from a click.",
                       isOn: $highlight.pulseShowsHold.revealing())
            .featureSpot("clip-pulse-hold")
        Reveal(isShown: highlight.pulseShowsHold) {
            ValueSlider(title: String(localized: "Counts as long after"), symbol: "timer", value: $highlight.holdDelay,
                        range: PointerHighlight.holdDelayRange, format: "%.2f s", step: 0.1, ends: .time)
            ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.holdSize,
                        range: PointerHighlight.holdSizeRange, format: "%.2f×", step: 0.1, ends: .size)
            ValueSlider(title: String(localized: "Fill"), symbol: "circle.inset.filled", value: $highlight.holdFill,
                        range: PointerHighlight.holdFillRange, format: "%.0f%%", scale: 100, step: 0.1, ends: .opacity)
            ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.holdLineWidth,
                        range: PointerHighlight.holdLineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
            SettingsToggle("Breathe while held", symbol: "wind",
                           caption: "The ring grows a little and back while you hold the button.", isOn: $highlight.holdBreathes)
        }
    }
}
