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
                               isOn: $highlight.showsRing)
                    .featureSpot("clip-ring-toggle")
                ValueSlider(title: String(localized: "Ring size"), symbol: "arrow.up.left.and.arrow.down.right",
                            value: $highlight.ringSize, range: PointerHighlight.sizeRange, format: "%.1f×",
                            spot: "clip-ring-size")
                    .disabled(!highlight.showsRing)
            }
            .featureSpot("highlight")
        }
    }

    /// Draws the ring even while it's off, dimmed, so its size still shows.
    private var sample: HighlightPreviewSample {
        var style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        style.showsRing = true
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale)
    }
}
