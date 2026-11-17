import SwiftUI

/// Preferences › Pulse: a ring that grows and fades where you click.
struct PulsePreferences: View {
    @Bindable var highlight: PointerHighlight
    let pair: PointerPair
    let pointerScale: Double

    var body: some View {
        SettingsPage("Pulse") {
            SettingsCard(anchor: "highlight.pulse") {
                SettingsToggle("Show a pulse on each click", symbol: "circle.circle",
                               caption: "A ring that grows and fades where you click.",
                               isOn: $highlight.pulseOn.revealing())
                    .resettable($highlight.pulseOn, to: PointerHighlight.factory.pulseOn)
                Reveal(isShown: highlight.pulseOn) { PulseRows(highlight: highlight, style: style, pair: pair) }
            }
            .featureSpot("pulse")
            Reveal(isShown: highlight.pulseOn) {
                SettingsCard("Long presses", anchor: "highlight.hold") {
                    HoldRows(highlight: highlight)
                }
            }
        }
    }

    /// The pulse as it shows on screen, for the style cards. Size is the one slider for how large
    /// it grows; each style's saved growth (no longer shown) still applies, so no look changes.
    private var style: HighlightStyle {
        HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
    }
}

/// Everything that shapes a pulse, under its switch: right-clicks and the style first, then the
/// rows every style shows, then the rows that come and go with the style, at the bottom so nothing above them moves.
private struct PulseRows: View {
    @Bindable var highlight: PointerHighlight
    /// The pulse as drawn on screen, for the style cards.
    let style: HighlightStyle
    let pair: PointerPair

    var body: some View {
        SettingsToggle("Pulse on right-clicks too", symbol: "cursorarrow.click", isOn: $highlight.pulsesOnRightClick)
        .resettable($highlight.pulsesOnRightClick, to: PointerHighlight.factory.pulsesOnRightClick)
        SettingsRow("Style", symbol: "circle.circle", caption: "Move the pointer over a card to play it at its real size.") {
            EmptyView()
        }
        .resettable($highlight.pulseStyle, to: PointerHighlight.factory.pulseStyle)
        PulseStylePicker(selection: $highlight.pulseStyle.revealing(), highlight: highlight, style: style, pair: pair)
            .featureSpot("clip-pulse-style")
        SharedPulseRows(highlight: highlight)
        // Frost has a color row of its own, Bokeh keeps its clip's colors, and both glow instead of having an outline.
        Reveal(isShown: !highlight.pulseStyle.hasOwnColors) {
            ColorSourcePicker(usesPair: $highlight.pulseUsesPairColor, color: $highlight.pulseColor,
                              defaultUsesPair: PointerHighlight.factory.pulseUsesPairColor, defaultColor: PointerHighlight.factory.pulseColor)
            OutlineRows(highlight: highlight)
        }
        Reveal(isShown: highlight.pulseStyle == .ring) { RingStyleRows(highlight: highlight) }
        Reveal(isShown: highlight.pulseStyle == .ripple) { RippleStyleRows(highlight: highlight) }
        Reveal(isShown: highlight.pulseStyle == .frost) { FrostStyleRows(highlight: highlight) }
        Reveal(isShown: highlight.pulseStyle == .bokeh) {
            ValueSlider(title: String(localized: "Speed"), symbol: "speedometer",
                        caption: String(localized: "1× plays it at the speed of the clip it was made from."),
                        value: $highlight.bokehSpeed, range: PointerHighlight.bokehSpeedRange, format: "%.2f×", ends: .speed)
            .resettable($highlight.bokehSpeed, to: PointerHighlight.factory.bokehSpeed)
            ValueSlider(title: String(localized: "Blur"), symbol: "aqi.medium",
                        caption: String(localized: "How soft the squares and their glow are. 0% draws sharp shapes with no glow; 100% is the clip's blur."),
                        value: $highlight.bokehBlur, range: PointerHighlight.bokehBlurRange, format: "%.0f%%", scale: 100,
                        step: 0.05, ends: .blur)
            .resettable($highlight.bokehBlur, to: PointerHighlight.factory.bokehBlur)
            BokehColorPicker(source: $highlight.bokehColorSource, color: $highlight.bokehColor, look: $highlight.bokehColorLook,
                             defaultSource: PointerHighlight.factory.bokehColorSource, defaultColor: PointerHighlight.factory.bokehColor,
                             defaultLook: PointerHighlight.factory.bokehColorLook,
                             lookColor: highlight.bokehColorSource == .custom ? highlight.bokehColor : pair.highlightColor,
                             style: style, pair: pair)
            BokehShapeRows(highlight: highlight, style: style, pair: pair)
        }
    }
}

/// Size for every style, and Length for all but Bokeh, which has a Speed of its own at the bottom.
/// Frost's Length is its own; Ring and Ripple share theirs.
private struct SharedPulseRows: View {
    @Bindable var highlight: PointerHighlight

    /// Frost's own Length, or the one Ring and Ripple share.
    private var length: ReferenceWritableKeyPath<PointerHighlight, Double> {
        highlight.pulseStyle == .frost ? \.frostDuration : \.pulseDuration
    }

    var body: some View {
        ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.pulseSize,
                    range: PointerHighlight.pulseSizeRange, format: "%.1f×", spot: "clip-pulse-size", ends: .size)
        .resettable($highlight.pulseSize, to: PointerHighlight.factory.pulseSize)
        Reveal(isShown: highlight.pulseStyle != .bokeh) {
            ValueSlider(title: String(localized: "Length"), symbol: "timer", value: $highlight[dynamicMember: length],
                        range: PointerHighlight.pulseDurationRange, format: "%.2f s", ends: .time)
            .resettable($highlight[dynamicMember: length], to: PointerHighlight.factory[keyPath: length])
        }
    }
}

/// Which shapes Bokeh's clicks use: all of them as in the clip, or the ones checked on their cards,
/// which come and go at the bottom.
private struct BokehShapeRows: View {
    @Bindable var highlight: PointerHighlight
    let style: HighlightStyle
    let pair: PointerPair

    var body: some View {
        SettingsChoice(title: Text("Shapes"), symbol: "pentagon", caption: caption,
                       selection: $highlight.bokehShapeChoice.revealing(), label: \.title)
        .resettable($highlight.bokehShapeChoice, to: PointerHighlight.factory.bokehShapeChoice)
        Reveal(isShown: highlight.bokehShapeChoice == .custom) {
            BokehShapePicker(highlight: highlight, style: style, pair: pair)
        }
    }

    private var caption: Text {
        switch highlight.bokehShapeChoice {
        case .all: Text("Every shape, as often as in the clip.")
        case .custom: Text("Only the checked shapes, each as likely. Move the pointer over a card to play it.")
        }
    }
}

/// The dark outline behind Ring and Ripple lines, with its width under its switch.
private struct OutlineRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle("Dark outline", symbol: "circle.dashed.inset.filled",
                       caption: "Draws each pulse over the pair's dark color, as the laser's outline, so it stays clear on light backgrounds.",
                       isOn: $highlight.pulseOutlined.revealing())
        .resettable($highlight.pulseOutlined, to: PointerHighlight.factory.pulseOutlined)
        Reveal(isShown: highlight.pulseOutlined) {
            ValueSlider(title: String(localized: "Outline width"), symbol: "lineweight", value: $highlight.pulseOutlineWidth,
                        range: PointerHighlight.pulseOutlineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
            .resettable($highlight.pulseOutlineWidth, to: PointerHighlight.factory.pulseOutlineWidth)
        }
    }
}

/// The Ring style: one ring.
private struct RingStyleRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.pulseLineWidth,
                    range: PointerHighlight.lineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
        .resettable($highlight.pulseLineWidth, to: PointerHighlight.factory.pulseLineWidth)
        ValueSlider(title: String(localized: "Starting opacity"), symbol: "circle.lefthalf.filled", value: $highlight.pulseOpacity,
                    range: PointerHighlight.opacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
        .resettable($highlight.pulseOpacity, to: PointerHighlight.factory.pulseOpacity)
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
        .resettable($highlight.rippleWaves, to: PointerHighlight.factory.rippleWaves)
        ValueSlider(title: String(localized: "Gap between waves"), symbol: "arrow.left.and.right", value: $highlight.rippleSpacing,
                    range: PointerHighlight.rippleSpacingRange, format: "%.0f%%", scale: 100, step: 0.01, ends: .spread)
        .resettable($highlight.rippleSpacing, to: PointerHighlight.factory.rippleSpacing)
        ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.rippleLineWidth,
                    range: PointerHighlight.rippleLineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
        .resettable($highlight.rippleLineWidth, to: PointerHighlight.factory.rippleLineWidth)
        ValueSlider(title: String(localized: "Starting opacity"), symbol: "circle.lefthalf.filled", value: $highlight.rippleOpacity,
                    range: PointerHighlight.opacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
        .resettable($highlight.rippleOpacity, to: PointerHighlight.factory.rippleOpacity)
    }
}

/// The Frost style: a flash, a glowing ring and ice shards.
private struct FrostStyleRows: View {
    @Bindable var highlight: PointerHighlight

    private var shards: Binding<Double> {
        Binding(get: { Double(highlight.frostShards) }, set: { highlight.frostShards = Int($0.rounded()) })
    }

    var body: some View {
        let range = PointerHighlight.frostShardsRange
        SettingsToggle("Flash", symbol: "sparkle", caption: "A bright white flash under the pointer as the click lands.",
                       isOn: $highlight.frostFlash)
        .resettable($highlight.frostFlash, to: PointerHighlight.factory.frostFlash)
        ValueSlider(title: String(localized: "Shards"), symbol: "rhombus", value: shards,
                    range: Double(range.lowerBound)...Double(range.upperBound), format: "%.0f", step: 1, ends: .count)
        .resettable($highlight.frostShards, to: PointerHighlight.factory.frostShards)
        // Last, since its custom color row comes and goes.
        FrostColorPicker(source: $highlight.frostColorSource, color: $highlight.frostColor,
                         defaultSource: PointerHighlight.factory.frostColorSource, defaultColor: PointerHighlight.factory.frostColor)
    }
}

/// The ring a long press keeps under the pointer, under its own switch.
private struct HoldRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle("Show long presses", symbol: "hand.tap",
                       caption: "Holding the button keeps a small filled ring under the pointer, and letting go sends out a pulse, so a press looks different from a click.",
                       isOn: $highlight.pulseShowsHold.revealing())
            .resettable($highlight.pulseShowsHold, to: PointerHighlight.factory.pulseShowsHold)
            .featureSpot("clip-pulse-hold")
        Reveal(isShown: highlight.pulseShowsHold) {
            ValueSlider(title: String(localized: "Counts as long after"), symbol: "timer", value: $highlight.holdDelay,
                        range: PointerHighlight.holdDelayRange, format: "%.2f s", step: 0.1, ends: .time)
            .resettable($highlight.holdDelay, to: PointerHighlight.factory.holdDelay)
            ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.holdSize,
                        range: PointerHighlight.holdSizeRange, format: "%.2f×", step: 0.1, ends: .size)
            .resettable($highlight.holdSize, to: PointerHighlight.factory.holdSize)
            ValueSlider(title: String(localized: "Fill"), symbol: "circle.inset.filled", value: $highlight.holdFill,
                        range: PointerHighlight.holdFillRange, format: "%.0f%%", scale: 100, step: 0.1, ends: .opacity)
            .resettable($highlight.holdFill, to: PointerHighlight.factory.holdFill)
            ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.holdLineWidth,
                        range: PointerHighlight.holdLineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
            .resettable($highlight.holdLineWidth, to: PointerHighlight.factory.holdLineWidth)
            SettingsToggle("Breathe while held", symbol: "wind",
                           caption: "The ring grows a little and back while you hold the button.", isOn: $highlight.holdBreathes)
            .resettable($highlight.holdBreathes, to: PointerHighlight.factory.holdBreathes)
        }
    }
}
