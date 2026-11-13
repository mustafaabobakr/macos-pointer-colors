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
                               isOn: $highlight.laserOn.revealing())
                Reveal(isShown: highlight.laserOn) { LaserRows(highlight: highlight) }
            }
            .featureSpot("laser")
            SettingsCard("Screenshots", anchor: "highlight.laserShot") {
                if !highlight.laserOn {
                    Text("Turn on Show the laser above to take screenshots of your drawings.")
                        .appFont(.caption).foregroundStyle(.secondary)
                }
                LaserShotRows(highlight: highlight)
                    .disabled(!highlight.laserOn)
            }
            .animation(.reveal, value: highlight.laserOn)
        }
    }

    /// The laser alone, its trail and dot as the settings below draw them, as large as on screen.
    private var sample: HighlightPreviewSample {
        var style = HighlightStyle(settings: highlight, pair: pair, pointerScale: pointerScale)
        style.showsRing = false
        return HighlightPreviewSample(style: style, pressScale: highlight.pressScale, showsTrail: highlight.laserTrail,
                                      showsDot: highlight.laserDot != .hidden, realSize: true)
    }
}

/// Everything that shapes the laser, under its switch.
private struct LaserRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsMenu("Look", symbol: "wand.and.rays",
                     caption: "Classic draws a white center with an outline. GoodNotes draws a glowing line around a white core that's thick when you move slowly and thin when you move fast, and a solid dot, and keeps the trail whole before fading it out.",
                     selection: $highlight.laserLook.revealing()) {
            ForEach(LaserLook.allCases) { Text($0.title).tag($0) }
        }
        .featureSpot("clip-laser-look")
        Reveal(isShown: highlight.laserLook == .classic) { ClassicLookRows(highlight: highlight) }
        Reveal(isShown: highlight.laserLook == .goodNotes) { GoodNotesLookRows(highlight: highlight) }
        ColorSourcePicker(usesPair: $highlight.laserUsesPairColor, color: $highlight.laserColor)
        ValueSlider(title: String(localized: "Size"), symbol: "arrow.up.left.and.arrow.down.right", value: $highlight.laserSize,
                    range: PointerHighlight.sizeRange, format: "%.1f×", spot: "clip-laser-size", ends: .size)
        SettingsMenu("Outline", symbol: "circle.dashed",
                     caption: "The thin edge around the dot and along the trail. The pair's dark color keeps the laser clear on light backgrounds.",
                     selection: $highlight.laserOutline.revealing()) {
            ForEach(LaserOutline.allCases) { Text($0.title).tag($0) }
        }
        .featureSpot("clip-laser-outline")
        Reveal(isShown: highlight.laserOutline != .none) {
            ValueSlider(title: String(localized: "Outline opacity"), symbol: "circle.lefthalf.filled",
                        value: $highlight.laserOutlineOpacity,
                        range: PointerHighlight.outlineOpacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
        }
        SettingsToggle("Draw a trail while dragging", symbol: "scribble",
                       caption: "Hold the mouse button and move to draw; the trail fades after you let go.",
                       isOn: $highlight.laserTrail.revealing())
        Reveal(isShown: highlight.laserTrail) {
            ValueSlider(title: String(localized: "Trail fades after"), symbol: "timer", value: $highlight.laserTrailFade,
                        range: PointerHighlight.trailFadeRange, format: "%.1f s", ends: .time)
            HoldKeysRows(highlight: highlight)
        }
        SettingsMenu("Dot", symbol: "smallcircle.filled.circle",
                     caption: "When the glowing dot follows the pointer. While drawing, it shows only at the tip of a trail.",
                     selection: $highlight.laserDot.revealing()) {
            ForEach(LaserDotMode.allCases) { Text($0.title).tag($0) }
        }
        Reveal(isShown: highlight.laserDot != .hidden) {
            ValueSlider(title: String(localized: "Dot fades after"), symbol: "timer", value: $highlight.laserDotFade,
                        range: PointerHighlight.dotFadeRange, format: "%.2f s", step: 0.2, ends: .time)
        }
    }
}

/// The Classic look: how solid its trail is, how much it glows, and how white its middle is.
private struct ClassicLookRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ValueSlider(title: String(localized: "Trail opacity"), symbol: "circle.lefthalf.filled", value: $highlight.laserTrailOpacity,
                    range: PointerHighlight.trailOpacityRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .opacity)
        ValueSlider(title: String(localized: "Glow"), symbol: "sun.max", value: $highlight.laserGlow,
                    range: PointerHighlight.glowRange, format: "%.0f%%", scale: 100, step: 0.05, ends: .brightness)
        ValueSlider(title: String(localized: "Middle lightness"), symbol: "circle.circle", value: $highlight.laserCoreLightness,
                    range: PointerHighlight.coreLightnessRange, format: "%.0f%%", scale: 100, step: 0.1, ends: .brightness)
    }
}

/// The GoodNotes look: how long a finished trail takes to vanish, and how wide its edge is.
private struct GoodNotesLookRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        ValueSlider(title: String(localized: "Fade-out"), symbol: "timer", value: $highlight.laserFadeOut,
                    range: PointerHighlight.fadeOutRange, format: "%.2f s", step: 0.1, ends: .time)
        Reveal(isShown: highlight.laserOutline != .none) {
            ValueSlider(title: String(localized: "Edge width"), symbol: "lineweight", value: $highlight.laserRim,
                        range: PointerHighlight.rimRange, format: "%.1f pt", step: 0.5, ends: .width)
        }
    }
}

/// Whether the laser draws only while keys are held and, once it does, which keys and whether
/// that drag clicks the app underneath. Shown only while the trail is on.
private struct HoldKeysRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        Reveal(isShown: highlight.laserNeedsKeys) { blockClicks }
        SettingsToggle(title: Text("Draw only while holding \(highlight.laserKeys.title)"), symbol: "command",
                       caption: Text("A \(highlight.laserKeys.symbols)-drag draws the laser. Without \(highlight.laserKeys.symbols), clicks and drags work as usual."),
                       isOn: $highlight.laserNeedsKeys.revealing())
        Reveal(isShown: highlight.laserNeedsKeys) { keys }
    }

    private var blockClicks: some View {
        SettingsToggle(title: Text("Block clicks while drawing"), symbol: "hand.raised",
                       caption: Text("A \(highlight.laserKeys.symbols)-drag doesn't click the app underneath, so no text gets selected. Off, the drag draws and also reaches the app. Works with Draw only while holding \(highlight.laserKeys.title)."),
                       isOn: $highlight.laserBlocksClicks)
    }

    private var keys: some View {
        SettingsRow("Keys to hold", symbol: "keyboard",
                    caption: "Click, then press ⌘, ⌥, ⌃ or ⇧, alone or together, and let go.") {
            HoldKeyRecorder(keys: highlight.laserKeys) { highlight.laserKeys = $0 }
        }
    }
}
