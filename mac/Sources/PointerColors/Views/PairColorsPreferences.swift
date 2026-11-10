import SwiftUI

/// Preferences › Pair colors: the pulse and laser colors for one pair at a time, starting with the
/// pair on screen.
struct PairColorsPreferences: View {
    let highlight: PointerHighlight
    let pairs: [PointerPair]
    let current: PointerPair
    @State private var pairID: String?

    private var pair: PointerPair { pairs.first { $0.id == pairID } ?? current }

    var body: some View {
        SettingsPage("Pair colors") {
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
            .featureSpot("highlight-pair-colors")
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
