import SwiftUI

/// Preferences › Ring: a ring that stays around the pointer.
struct RingPreferences: View {
    @Bindable var highlight: PointerHighlight
    let pair: PointerPair
    let pointerScale: Double

    var body: some View {
        SettingsPage("Ring") {
            SettingsCard(anchor: "highlight.ring") {
                HighlightPreviewBanner(scene: .ring, pair: pair, sample: sample, isOn: highlight.showsRing)
                SettingsToggle("Ring around the pointer", symbol: "circle.dashed",
                               caption: "Makes the pointer easy to follow. Works with any highlight, or on its own.",
                               isOn: $highlight.showsRing.revealing())
                    .featureSpot("clip-ring-toggle")
                Reveal(isShown: highlight.showsRing) { RingRows(highlight: highlight) }
            }
            .featureSpot("highlight")
        }
    }

    /// Draws the ring even while it's off, dimmed, so its size still shows, as large as on screen.
    private var sample: HighlightPreviewSample {
        var style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        style.showsRing = true
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale, realSize: true)
    }
}

/// The ring's color, size and edge, under its switch.
private struct RingRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ColorSourcePicker(usesPair: $highlight.ringUsesPairColor, color: $highlight.ringColor)
        ValueSlider(title: String(localized: "Ring size"), symbol: "arrow.up.left.and.arrow.down.right",
                    value: $highlight.ringSize, range: PointerHighlight.ringSizeRange, format: "%.1f×",
                    spot: "clip-ring-size", ends: .size)
        ValueSlider(title: String(localized: "Fill"), symbol: "circle.inset.filled", value: $highlight.ringFill,
                    range: PointerHighlight.fillRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
        ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $highlight.ringLineWidth,
                    range: PointerHighlight.lineWidthRange, format: "%.1f pt", step: 0.5, ends: .width)
        ValueSlider(title: String(localized: "Line opacity"), symbol: "circle.lefthalf.filled", value: $highlight.ringOpacity,
                    range: PointerHighlight.opacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
    }
}
