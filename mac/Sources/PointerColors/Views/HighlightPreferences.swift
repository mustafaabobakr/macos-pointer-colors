import SwiftUI

/// Preferences › Highlight: the ring, and the pulse and laser for demos and recordings.
struct HighlightPreferences: View {
    @Bindable var highlight: PointerHighlight
    /// The pair on screen and the pointer size, so the demo looks like the real thing.
    let pair: PointerPair
    /// Pairs whose pulse and laser colors can be set.
    let pairs: [PointerPair]
    let pointerScale: Double

    private var style: HighlightStyle { HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale) }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Highlight")
                    Text("Click a picture to turn it on or off. Use one, both, or neither.")
                        .appFont(.caption).foregroundStyle(.secondary)
                }
                HighlightPreviewCards(highlight: highlight, style: style, pair: pair)
                HighlightDemoPad(highlight: highlight, style: style)
                Toggle(isOn: $highlight.showsRing) {
                    Text("Ring around the pointer")
                    Text("Makes the pointer easy to follow. Works with any highlight, or on its own.")
                }
            }
            PulseSection(highlight: highlight)
            LaserSection(highlight: highlight)
            PairColorsSection(highlight: highlight, pairs: pairs, current: pair)
        }
        .formStyle(.grouped)
    }
}

private struct PulseSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        Section("Pulse") {
            ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor,
                              pairHint: String(localized: "Uses the pair's color, set below for each pair."))
            ValueSlider(title: String(localized: "Size"), value: $highlight.pulseSize,
                        range: PointerHighlight.sizeRange, format: "%.1f×")
            ValueSlider(title: String(localized: "Length"), value: $highlight.pulseDuration,
                        range: PointerHighlight.pulseDurationRange, format: "%.2f s")
            Toggle("Pulse on right-clicks too", isOn: $highlight.pulsesOnRightClick)
        }
        .disabled(!highlight.pulseOn)
    }
}

private struct LaserSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        Section("Laser") {
            ColorSourcePicker(usesPair: $highlight.laserUsesPairColor, color: $highlight.laserColor,
                              pairHint: String(localized: "Uses the pair's color, set below for each pair."))
            ValueSlider(title: String(localized: "Size"), value: $highlight.laserSize,
                        range: PointerHighlight.sizeRange, format: "%.1f×")
            Toggle(isOn: $highlight.laserTrail) {
                Text("Draw a trail while dragging")
                Text("Hold the mouse button and move to draw; the trail fades after you let go.")
            }
            ValueSlider(title: String(localized: "Trail fades after"), value: $highlight.laserTrailFade,
                        range: PointerHighlight.trailFadeRange, format: "%.1f s")
                .disabled(!highlight.laserTrail)
            Toggle(isOn: $highlight.laserNeedsOption) {
                Text("Draw only while holding ⌥ Option")
                Text("A ⌥-drag draws the laser and doesn't click the app underneath, so no text gets selected. Without ⌥, clicks and drags work as usual.")
            }
            .disabled(!highlight.laserTrail)
        }
        .disabled(!highlight.laserOn)
    }
}

/// The pulse and laser colors for one pair at a time, starting with the pair on screen.
private struct PairColorsSection: View {
    let highlight: PointerHighlight
    let pairs: [PointerPair]
    let current: PointerPair
    @State private var pairID: String?

    private var pair: PointerPair { pairs.first { $0.id == pairID } ?? current }

    var body: some View {
        Section {
            LabeledContent("Pair") {
                PairMenuButton(selection: Binding(get: { pair.id }, set: { pairID = $0 }), pairs: pairs,
                               accessibilityTitle: String(localized: "Pair to set colors for"), allowsNone: false)
            }
            PairColorRow(title: String(localized: "Pulse color"),
                         color: highlight.pulsePairColor(pair), isSet: highlight.pairPulseColors[pair.id] != nil,
                         set: { highlight.setPulseColor($0, for: pair) })
            PairColorRow(title: String(localized: "Laser color"),
                         color: highlight.laserPairColor(pair), isSet: highlight.pairLaserColors[pair.id] != nil,
                         set: { highlight.setLaserColor($0, for: pair) })
        } header: {
            Text("Colors for each pair")
        } footer: {
            Text("Used when Color is set to Pointer pair. Without a color of its own, a pair uses the brighter of its outline and fill.")
                .appFont(.caption).foregroundStyle(.secondary)
        }
    }
}

/// A color well for one pair, with Reset once it has a color of its own.
private struct PairColorRow: View {
    let title: String
    let color: RGBA
    let isSet: Bool
    let set: (RGBA?) -> Void

    var body: some View {
        HStack {
            ColorPicker(title, selection: Binding(get: { color.color }, set: { set(RGBA($0)) }), supportsOpacity: false)
            if isSet {
                Button("Reset") { set(nil) }.controlSize(.small)
            }
        }
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
