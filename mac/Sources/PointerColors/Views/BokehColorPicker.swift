import SwiftUI

/// The Bokeh pulse's color: gold, the pair's, or a custom one picked here. The flying squares
/// take a pale shade of it, and the warm ones the color itself.
struct BokehColorPicker: View {
    @Binding var source: BokehColorSource
    @Binding var color: RGBA

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
    }

    private var caption: Text {
        switch source {
        case .gold: Text("Pale gold and amber.")
        case .pair: Text("Uses the brighter of the pair's outline and fill, so it follows the pair on each display.")
        case .custom: Text("Uses the color you pick.")
        }
    }

    private func title(of source: BokehColorSource) -> Text {
        switch source {
        case .gold: Text("Gold")
        case .pair: Text("Pointer pair")
        case .custom: Text("Custom")
        }
    }
}
