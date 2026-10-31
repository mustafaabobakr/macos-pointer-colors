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
        SettingsPage("Highlight") {
            SettingsCard("Highlight", anchor: "highlight.highlight") {
                Text("Click a picture to turn it on or off. Use one, both, or neither.")
                    .appFont(.caption).foregroundStyle(.secondary)
                HighlightPreviewCards(highlight: highlight, style: style, pair: pair)
                HighlightDemoPad(highlight: highlight, style: style).featureSpot("clip-demo-pad")
                SettingsToggle("Ring around the pointer", symbol: "circle.dashed",
                               caption: "Makes the pointer easy to follow. Works with any highlight, or on its own.",
                               isOn: $highlight.showsRing)
            }
            .featureSpot("highlight")
            PulseSection(highlight: highlight).featureSpot("pulse")
            LaserSection(highlight: highlight).featureSpot("laser")
            PressSection(highlight: highlight, pointerScale: pointerScale).featureSpot("press-shrink")
            PairColorsSection(highlight: highlight, pairs: pairs, current: pair).featureSpot("highlight-pair-colors")
        }
    }
}

private struct PressSection: View {
    @Bindable var highlight: PointerHighlight
    let pointerScale: Double

    private var caption: LocalizedStringKey {
        pointerScale > SystemPointer.minimumScale
            ? "The pointer gets smaller while the button is down, so every click feels pressed."
            : "The pointer gets smaller while the button is down. macOS can't draw it smaller than its smallest size, so make it bigger first."
    }

    var body: some View {
        SettingsCard("Press", anchor: "highlight.press") {
            SettingsToggle("Shrink the pointer on click", symbol: "arrow.down.right.and.arrow.up.left",
                           caption: caption, isOn: $highlight.shrinksOnPress)
                .featureSpot("clip-press-toggle")
            Group {
                ValueSlider(title: String(localized: "Pressed size"), symbol: "arrow.down.forward.and.arrow.up.backward",
                            value: $highlight.pressScale, range: PointerHighlight.pressScaleRange, format: "%.2f×",
                            spot: "clip-press-size")
                ValueSlider(title: String(localized: "Shrink in"), symbol: "timer", value: $highlight.pressDownDuration,
                            range: PointerHighlight.pressDurationRange, format: "%.2f s")
                ValueSlider(title: String(localized: "Grow back in"), symbol: "timer", value: $highlight.pressUpDuration,
                            range: PointerHighlight.pressDurationRange, format: "%.2f s")
                SettingsMenu("Animation", symbol: "waveform.path",
                             caption: "Bounce goes a little past the size, then settles, like a spring. 0 s skips the animation.",
                             selection: $highlight.pressCurve) {
                    ForEach(PressCurve.allCases) { Text($0.title).tag($0) }
                }
                .featureSpot("clip-press-curve")
                SettingsToggle("Shrink on right-clicks too", symbol: "cursorarrow.click", isOn: $highlight.shrinksOnRightClick)
            }
            .disabled(!highlight.shrinksOnPress)
        }
    }
}

private struct PulseSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsCard("Pulse", anchor: "highlight.pulse") {
            ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor,
                              pairHint: String(localized: "Uses the pair's color, set below for each pair."))
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
        }
        .disabled(!highlight.pulseOn)
    }
}

private struct LaserSection: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsCard("Laser", anchor: "highlight.laser") {
            ColorSourcePicker(usesPair: $highlight.laserUsesPairColor, color: $highlight.laserColor,
                              pairHint: String(localized: "Uses the pair's color, set below for each pair."))
            ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.laserSize,
                        range: PointerHighlight.sizeRange, format: "%.1f×")
                .featureSpot("clip-laser-size")
            SettingsMenu("Outline", symbol: "circle.dashed",
                         caption: "The thin edge around the dot and along the trail. The pair's dark color keeps the laser clear on light backgrounds.",
                         selection: $highlight.laserOutline) {
                ForEach(LaserOutline.allCases) { Text($0.title).tag($0) }
            }
            .featureSpot("clip-laser-outline")
            SettingsToggle("Draw a trail while dragging", symbol: "scribble",
                           caption: "Hold the mouse button and move to draw; the trail fades after you let go.",
                           isOn: $highlight.laserTrail)
            ValueSlider(title: String(localized: "Trail fades after"), symbol: "timer", value: $highlight.laserTrailFade,
                        range: PointerHighlight.trailFadeRange, format: "%.1f s")
                .disabled(!highlight.laserTrail)
            HoldKeysRows(highlight: highlight)
            SettingsMenu("Dot", symbol: "smallcircle.filled.circle",
                         caption: "When the glowing dot follows the pointer. While drawing, it shows only at the tip of a trail.",
                         selection: $highlight.laserDot) {
                ForEach(LaserDotMode.allCases) { Text($0.title).tag($0) }
            }
        }
        .disabled(!highlight.laserOn)
    }
}

/// Whether the laser draws only while keys are held, and which keys.
private struct HoldKeysRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle(title: Text("Draw only while holding \(highlight.laserKeys.title)"), symbol: "command",
                       caption: Text("A \(highlight.laserKeys.symbols)-drag draws the laser and doesn't click the app underneath, so no text gets selected. Without \(highlight.laserKeys.symbols), clicks and drags work as usual."),
                       isOn: $highlight.laserNeedsKeys)
            .disabled(!highlight.laserTrail)
        SettingsRow("Keys to hold", symbol: "keyboard",
                    caption: "Click, then press ⌘, ⌥, ⌃ or ⇧, alone or together, and let go.") {
            HoldKeyRecorder(keys: highlight.laserKeys) { highlight.laserKeys = $0 }
        }
        .disabled(!highlight.laserTrail || !highlight.laserNeedsKeys)
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
        SettingsCard("Colors for each pair", anchor: "highlight.pairColors") {
            SettingsRow("Pair", symbol: "cursorarrow") {
                PairMenuButton(selection: Binding(get: { pair.id }, set: { pairID = $0 }), pairs: pairs,
                               accessibilityTitle: String(localized: "Pair to set colors for"), allowsNone: false)
                    .fixedSize()
            }
            PairColorRow(title: String(localized: "Pulse color"), symbol: "circle.circle",
                         color: highlight.pulsePairColor(pair), isSet: highlight.pairPulseColors[pair.id] != nil,
                         set: { highlight.setPulseColor($0, for: pair) })
                .featureSpot("clip-pair-pulse-color")
            PairColorRow(title: String(localized: "Laser color"), symbol: "smallcircle.filled.circle",
                         color: highlight.laserPairColor(pair), isSet: highlight.pairLaserColors[pair.id] != nil,
                         set: { highlight.setLaserColor($0, for: pair) })
            Text("Used when Color is set to Pointer pair. Without a color of its own, a pair uses the brighter of its outline and fill.")
                .appFont(.caption).foregroundStyle(.secondary)
        }
    }
}

/// A color well for one pair, with Reset once it has a color of its own.
private struct PairColorRow: View {
    let title: String
    let symbol: String
    let color: RGBA
    let isSet: Bool
    let set: (RGBA?) -> Void

    var body: some View {
        SettingsRow(symbol: symbol, title: Text(title)) {
            if isSet {
                Button("Reset") { set(nil) }.controlSize(.small)
            }
            ColorPicker(title, selection: Binding(get: { color.color }, set: { set(RGBA($0)) }), supportsOpacity: false)
                .labelsHidden()
        }
    }
}

/// The pair's colors, or a custom color picked here.
private struct ColorSourcePicker: View {
    @Binding var usesPair: Bool
    @Binding var color: RGBA
    let pairHint: String

    var body: some View {
        SettingsMenu(title: Text("Color"), symbol: "paintpalette",
                     caption: Text(usesPair ? pairHint : String(localized: "Uses the color you pick.")),
                     selection: $usesPair) {
            Text("Pointer pair").tag(true)
            Text("Custom").tag(false)
        }
        if !usesPair {
            SettingsRow("Custom color", symbol: "eyedropper") {
                ColorPicker("Custom color", selection: Binding(get: { color.color }, set: { color = RGBA($0) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }
}

private struct ValueSlider: View {
    let title: String
    let symbol: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String
    /// Marks the slider itself, not its row, for a clip that drags it.
    var spot: String?

    var body: some View {
        SettingsRow(symbol: symbol, title: Text(title)) {
            Slider(value: $value, in: range).accessibilityLabel(title).featureSpot(spot ?? "")
                .frame(width: 220)
            Text(String(format: format, value)).monospacedDigit().foregroundStyle(.secondary)
                .frame(minWidth: 52, alignment: .trailing)
        }
    }
}
