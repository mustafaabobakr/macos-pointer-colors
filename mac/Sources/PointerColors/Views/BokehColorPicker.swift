import SwiftUI

/// Bokeh's one color source: Golden hour (the clip's own), the pair's, or a custom one picked here, with
/// how the pair's or custom color turns into the squares' colors. The middle square and every
/// flying square are shades of it.
struct BokehColorPicker: View {
    @Binding var source: BokehColorSource
    @Binding var color: RGBA
    @Binding var look: BokehColorLook
    /// The color the look cards are built from: the pair's or the custom one.
    let lookColor: RGBA
    /// The pulse as drawn on screen, and the pair, for the look cards' pictures.
    let style: HighlightStyle
    let pair: PointerPair

    var body: some View {
        SettingsChoice(title: Text("Color"), symbol: "paintpalette", caption: caption,
                       selection: $source.revealing(), options: BokehColorSource.allCases) { source in
            title(of: source)
        }
        Reveal(isShown: source == .custom) {
            SettingsRow("Custom color", symbol: "eyedropper") {
                ColorPicker("Custom color", selection: Binding(get: { color.color }, set: { color = RGBA($0) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
        }
        // Last, since the cards are the tallest rows that come and go.
        Reveal(isShown: source != .clip) {
            SettingsRow(symbol: "swatchpalette", title: Text("Look"), caption: Text(look.summary)) { EmptyView() }
            BokehLookPicker(selection: $look, color: lookColor, style: style, pair: pair)
        }
    }

    private var caption: Text {
        switch source {
        case .clip: Text("Orange to pale gold, as in the clip.")
        case .pair: Text("Uses the brighter of the pair's outline and fill, so it follows the pair on each display.")
        case .custom: Text("Uses the color you pick.")
        }
    }

    private func title(of source: BokehColorSource) -> Text {
        switch source {
        case .clip: Text("Golden hour")
        case .pair: Text("Pointer pair")
        case .custom: Text("Custom")
        }
    }
}
