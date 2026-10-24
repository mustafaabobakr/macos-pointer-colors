import SwiftUI

/// Preferences › Highlight: the ring, and the pulse and laser for demos and recordings.
struct HighlightPreferences: View {
    @Bindable var highlight: PointerHighlight
    /// The pair on screen and the pointer size, so the demo looks like the real thing.
    let pair: PointerPair
    let pointerScale: Double

    private var style: HighlightStyle { HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale) }

    var body: some View {
        Form {
            Section {
                HighlightPreviewCards(mode: highlight.mode, style: style, pair: pair)
                HighlightDemoPad(highlight: highlight, style: style)
                Picker(selection: $highlight.mode) {
                    ForEach(HighlightMode.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Highlight")
                    Text("Pulse marks each click. Laser leaves a glowing dot and a trail as you drag.")
                }
                .pickerStyle(.segmented)
                Toggle(isOn: $highlight.showsRing) {
                    Text("Ring around the pointer")
                    Text("Makes the pointer easy to follow. Works with any highlight, or on its own.")
                }
            }
            PulseSection(highlight: highlight)
            LaserSection(highlight: highlight)
        }
        .formStyle(.grouped)
    }
}

private struct PulseSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        Section("Pulse") {
            ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor,
                              pairHint: String(localized: "Uses the outline of the pair on screen."))
            ValueSlider(title: String(localized: "Size"), value: $highlight.pulseSize,
                        range: PointerHighlight.sizeRange, format: "%.1f×")
            ValueSlider(title: String(localized: "Length"), value: $highlight.pulseDuration,
                        range: PointerHighlight.pulseDurationRange, format: "%.2f s")
            Toggle("Pulse on right-clicks too", isOn: $highlight.pulsesOnRightClick)
        }
        .disabled(highlight.mode != .pulse)
    }
}

private struct LaserSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        Section("Laser") {
            ColorSourcePicker(usesPair: $highlight.laserUsesPairColor, color: $highlight.laserColor,
                              pairHint: String(localized: "Glows in the outline and fill of the pair on screen."))
            ValueSlider(title: String(localized: "Size"), value: $highlight.laserSize,
                        range: PointerHighlight.sizeRange, format: "%.1f×")
            Toggle(isOn: $highlight.laserTrail) {
                Text("Draw a trail while dragging")
                Text("Hold the mouse button and move to draw; the trail fades after you let go.")
            }
            ValueSlider(title: String(localized: "Trail fades after"), value: $highlight.laserTrailFade,
                        range: PointerHighlight.trailFadeRange, format: "%.1f s")
                .disabled(!highlight.laserTrail)
        }
        .disabled(highlight.mode != .laser)
    }
}

/// The pair's colors, or a custom color picked here.
private struct ColorSourcePicker: View {
    @Binding var usesPair: Bool
    @Binding var color: RGBA
    let pairHint: String

    var body: some View {
        Picker(selection: $usesPair) {
            Text("Pointer pair").tag(true)
            Text("Custom").tag(false)
        } label: {
            Text("Color")
            Text(usesPair ? pairHint : String(localized: "Uses the color you pick."))
        }
        if !usesPair {
            ColorPicker("Custom color", selection: Binding(get: { color.color }, set: { color = RGBA($0) }),
                        supportsOpacity: false)
        }
    }
}

private struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range).accessibilityLabel(title)
                Text(String(format: format, value)).monospacedDigit().foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
    }
}
