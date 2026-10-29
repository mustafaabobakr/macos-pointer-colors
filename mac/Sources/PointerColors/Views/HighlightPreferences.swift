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
                HighlightDemoPad(highlight: highlight, style: style).featureSpot("clip-demo-pad")
                Toggle(isOn: $highlight.showsRing) {
                    Text("Ring around the pointer")
                    Text("Makes the pointer easy to follow. Works with any highlight, or on its own.")
                }
            }
            .featureSpot("highlight")
            PressSection(highlight: highlight, pointerScale: pointerScale).featureSpot("press-shrink")
            PulseSection(highlight: highlight).featureSpot("pulse")
            LaserSection(highlight: highlight).featureSpot("laser")
            PairColorsSection(highlight: highlight, pairs: pairs, current: pair).featureSpot("highlight-pair-colors")
        }
        .formStyle(.grouped)
    }
}

private struct PressSection: View {
    @Bindable var highlight: PointerHighlight
    let pointerScale: Double

    var body: some View {
        Section("Press") {
            Toggle(isOn: $highlight.shrinksOnPress) {
                Text("Shrink the pointer on click")
                if pointerScale > SystemPointer.minimumScale {
                    Text("The pointer gets smaller while the button is down, so every click feels pressed.")
                } else {
                    Text("The pointer gets smaller while the button is down. macOS can't draw it smaller than its smallest size, so make it bigger first.")
                }
            }
            .featureSpot("clip-press-toggle")
            Group {
                ValueSlider(title: String(localized: "Pressed size"), value: $highlight.pressScale,
                            range: PointerHighlight.pressScaleRange, format: "%.2f×")
                    .featureSpot("clip-press-size")
                ValueSlider(title: String(localized: "Shrink in"), value: $highlight.pressDownDuration,
                            range: PointerHighlight.pressDurationRange, format: "%.2f s")
                ValueSlider(title: String(localized: "Grow back in"), value: $highlight.pressUpDuration,
                            range: PointerHighlight.pressDurationRange, format: "%.2f s")
                Picker(selection: $highlight.pressCurve) {
                    ForEach(PressCurve.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Animation")
                    Text("Bounce goes a little past the size, then settles, like a spring. 0 s skips the animation.")
                }
                .featureSpot("clip-press-curve")
                Toggle("Shrink on right-clicks too", isOn: $highlight.shrinksOnRightClick)
            }
            .disabled(!highlight.shrinksOnPress)
        }
    }
}

private struct PulseSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        Section("Pulse") {
            ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor,
                              pairHint: String(localized: "Uses the pair's color, set below for each pair."))
            Picker("Style", selection: $highlight.pulseStyle) {
                ForEach(PulseStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .featureSpot("clip-pulse-style")
            ValueSlider(title: String(localized: "Size"), value: $highlight.pulseSize,
                        range: PointerHighlight.sizeRange, format: "%.1f×")
                .featureSpot("clip-pulse-size")
            ValueSlider(title: String(localized: "Length"), value: $highlight.pulseDuration,
                        range: PointerHighlight.pulseDurationRange, format: "%.2f s")
            Toggle("Pulse on right-clicks too", isOn: $highlight.pulsesOnRightClick)
            Toggle(isOn: $highlight.pulseShowsHold) {
                Text("Show long presses")
                Text("Holding the button keeps a small filled ring under the pointer, and letting go sends out a pulse, so a press looks different from a click.")
            }
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
                .featureSpot("clip-laser-size")
            Picker(selection: $highlight.laserOutline) {
                ForEach(LaserOutline.allCases) { Text($0.title).tag($0) }
            } label: {
                Text("Outline")
                Text("The thin edge around the dot and along the trail. The pair's dark color keeps the laser clear on light backgrounds.")
            }
            .featureSpot("clip-laser-outline")
            Toggle(isOn: $highlight.laserTrail) {
                Text("Draw a trail while dragging")
                Text("Hold the mouse button and move to draw; the trail fades after you let go.")
            }
            ValueSlider(title: String(localized: "Trail fades after"), value: $highlight.laserTrailFade,
                        range: PointerHighlight.trailFadeRange, format: "%.1f s")
                .disabled(!highlight.laserTrail)
            Toggle(isOn: $highlight.laserNeedsKeys) {
                Text("Draw only while holding \(highlight.laserKeys.title)")
                Text("A \(highlight.laserKeys.symbols)-drag draws the laser and doesn't click the app underneath, so no text gets selected. Without \(highlight.laserKeys.symbols), clicks and drags work as usual.")
            }
            .disabled(!highlight.laserTrail)
            LabeledContent {
                HoldKeyRecorder(keys: highlight.laserKeys) { highlight.laserKeys = $0 }
            } label: {
                Text("Keys to hold")
                Text("Click, then press ⌘, ⌥, ⌃ or ⇧, alone or together, and let go.")
            }
            .disabled(!highlight.laserTrail || !highlight.laserNeedsKeys)
            Picker(selection: $highlight.laserDot) {
                ForEach(LaserDotMode.allCases) { Text($0.title).tag($0) }
            } label: {
                Text("Dot")
                Text("When the glowing dot follows the pointer. While drawing, it shows only at the tip of a trail.")
            }
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
                .featureSpot("clip-pair-pulse-color")
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
