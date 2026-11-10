import SwiftUI

/// Preferences › Laser: a glowing dot that follows the pointer, and a fading trail while you drag.
struct LaserPreferences: View {
    @Bindable var highlight: PointerHighlight
    let pair: PointerPair
    let pointerScale: Double

    var body: some View {
        SettingsPage("Laser") {
            SettingsCard(anchor: "highlight.laser") {
                HighlightPreviewBanner(scene: .laser, pair: pair, sample: sample, isOn: highlight.laserOn)
                SettingsToggle("Show the laser", symbol: "scribble",
                               caption: "A glowing dot that follows the pointer, and a fading trail while you drag.",
                               isOn: $highlight.laserOn)
                LaserRows(highlight: highlight)
                    .disabled(!highlight.laserOn)
            }
            .featureSpot("laser")
        }
    }

    /// The laser alone, its trail and dot as the settings below draw them.
    private var sample: HighlightPreviewSample {
        var style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        style.showsRing = false
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale, showsTrail: highlight.laserTrail,
                                      showsDot: highlight.laserDot != .hidden)
    }
}

/// Everything that shapes the laser, under its switch.
private struct LaserRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsMenu("Look", symbol: "wand.and.rays",
                     caption: "Classic draws a white center with an outline. GoodNotes draws a glowing line around a white core that's thick when you move slowly and thin when you move fast, and a solid dot, and keeps the trail whole before fading it out.",
                     selection: $highlight.laserLook) {
            ForEach(LaserLook.allCases) { Text($0.title).tag($0) }
        }
        .featureSpot("clip-laser-look")
        ColorSourcePicker(usesPair: $highlight.laserUsesPairColor, color: $highlight.laserColor)
        ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.laserSize,
                    range: PointerHighlight.sizeRange, format: "%.1f×", spot: "clip-laser-size")
        SettingsMenu("Outline", symbol: "circle.dashed",
                     caption: "The thin edge around the dot and along the trail. The pair's dark color keeps the laser clear on light backgrounds.",
                     selection: $highlight.laserOutline) {
            ForEach(LaserOutline.allCases) { Text($0.title).tag($0) }
        }
        .featureSpot("clip-laser-outline")
        ValueSlider(title: String(localized: "Outline opacity"), symbol: "circle.lefthalf.filled",
                    value: $highlight.laserOutlineOpacity,
                    range: PointerHighlight.outlineOpacityRange, format: "%.0f%%", scale: 100, step: 0.05)
            .disabled(highlight.laserOutline == .none)
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
}

/// Whether the laser draws only while keys are held, which keys, and whether that drag clicks the app underneath.
private struct HoldKeysRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle(title: Text("Draw only while holding \(highlight.laserKeys.title)"), symbol: "command",
                       caption: Text("A \(highlight.laserKeys.symbols)-drag draws the laser. Without \(highlight.laserKeys.symbols), clicks and drags work as usual."),
                       isOn: $highlight.laserNeedsKeys)
            .disabled(!highlight.laserTrail)
        Group {
            SettingsRow("Keys to hold", symbol: "keyboard",
                        caption: "Click, then press ⌘, ⌥, ⌃ or ⇧, alone or together, and let go.") {
                HoldKeyRecorder(keys: highlight.laserKeys) { highlight.laserKeys = $0 }
            }
            SettingsToggle(title: Text("Block clicks while drawing"), symbol: "hand.raised",
                           caption: Text("A \(highlight.laserKeys.symbols)-drag doesn't click the app underneath, so no text gets selected. Off, the drag draws and also reaches the app."),
                           isOn: $highlight.laserBlocksClicks)
        }
        .disabled(!highlight.laserTrail || !highlight.laserNeedsKeys)
    }
}
