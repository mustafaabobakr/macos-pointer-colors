import SwiftUI

/// Builds the hover pictures for the Highlight settings: one per choice, each drawn with the
/// current settings and colors except for the one choice it shows.
@MainActor
struct HighlightSettingPreviews {
    let highlight: PointerHighlight
    let pair: PointerPair
    let style: HighlightStyle

    typealias Apply<Value> = (inout HighlightPreviewSample, Value) -> Void

    private var base: HighlightPreviewSample {
        HighlightPreviewSample(style: style, pressScale: highlight.pressScale, exactPress: true)
    }

    /// Off and On.
    func toggle(_ scene: HighlightPreviewScene, isOn: Bool, apply: Apply<Bool>) -> SettingPreviewStrip {
        options(scene, [false, true], current: isOn,
                label: { $0 ? String(localized: "On") : String(localized: "Off") }, apply: apply)
    }

    /// Pointer pair and Custom, for a Color menu.
    func colorSource(_ scene: HighlightPreviewScene, usesPair: Bool, apply: Apply<Bool>) -> SettingPreviewStrip {
        options(scene, [true, false], current: usesPair,
                label: { $0 ? String(localized: "Pointer pair") : String(localized: "Custom") }, apply: apply)
    }

    /// Each of a menu's choices.
    func options<Value: Equatable>(_ scene: HighlightPreviewScene, _ values: [Value], current: Value,
                                   label: (Value) -> String, apply: Apply<Value>) -> SettingPreviewStrip {
        let cases = values.map { value in
            var sample = base
            apply(&sample, value)
            return SettingPreviewCase(label: label(value), sample: sample, isCurrent: value == current)
        }
        return SettingPreviewStrip(scene: scene, pair: pair, cases: cases)
    }

    /// The smallest, the current and the largest value, labelled as the slider labels them.
    func slider(_ scene: HighlightPreviewScene, range: ClosedRange<Double>, value: Double, format: String,
                scale: Double = 1, apply: Apply<Double>) -> SettingPreviewStrip {
        options(scene, Self.stops(range, value), current: value,
                label: { String(format: format, $0 * scale) }, apply: apply)
    }

    /// Both ends and the current value; the middle instead when the value sits at an end.
    private static func stops(_ range: ClosedRange<Double>, _ value: Double) -> [Double] {
        let ends = [range.lowerBound, range.upperBound]
        let middle = ends.contains(value) ? (range.lowerBound + range.upperBound) / 2 : value
        return [range.lowerBound, middle, range.upperBound]
    }
}
