import SwiftUI

/// Preferences › Press: the pointer shrinks while a button is down.
struct PressPreferences: View {
    @Bindable var highlight: PointerHighlight
    let pair: PointerPair
    let pointerScale: Double

    private var caption: LocalizedStringKey {
        pointerScale > SystemPointer.minimumScale
            ? "The pointer gets smaller while the button is down, so every click feels pressed."
            : "The pointer gets smaller while the button is down. macOS can't draw it smaller than its smallest size, so make it bigger first."
    }

    var body: some View {
        SettingsPage("Press") {
            SettingsCard(anchor: "highlight.press") {
                HighlightPreviewBanner(scene: .press, pair: pair, sample: sample, isOn: highlight.shrinksOnPress)
                SettingsToggle("Shrink the pointer on click", symbol: "arrow.down.right.and.arrow.up.left",
                               caption: caption, isOn: $highlight.shrinksOnPress.revealing())
                    .featureSpot("clip-press-toggle")
                Reveal(isShown: highlight.shrinksOnPress) { PressRows(highlight: highlight) }
            }
            .featureSpot("press-shrink")
        }
    }

    /// The pressed size as set, not drawn larger than it is.
    private var sample: HighlightPreviewSample {
        let style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale, exactPress: true)
    }
}

/// How small, how fast and how the pointer shrinks, under its switch.
private struct PressRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ValueSlider(title: String(localized: "Pressed size"), symbol: "arrow.down.forward.and.arrow.up.backward",
                    value: $highlight.pressScale, range: PointerHighlight.pressScaleRange, format: "%.2f×",
                    spot: "clip-press-size", ends: .size)
        ValueSlider(title: String(localized: "Shrink in"), symbol: "timer", value: $highlight.pressDownDuration,
                    range: PointerHighlight.pressDurationRange, format: "%.2f s", ends: .time)
        ValueSlider(title: String(localized: "Grow back in"), symbol: "timer", value: $highlight.pressUpDuration,
                    range: PointerHighlight.pressDurationRange, format: "%.2f s", ends: .time)
        SettingsChoice("Animation", symbol: "waveform.path",
                     caption: "Bounce goes a little past the size, then settles, like a spring. 0 s skips the animation.",
                     selection: $highlight.pressCurve, label: \.title)
        .featureSpot("clip-press-curve")
        SettingsToggle("Shrink on right-clicks too", symbol: "cursorarrow.click", isOn: $highlight.shrinksOnRightClick)
    }
}
