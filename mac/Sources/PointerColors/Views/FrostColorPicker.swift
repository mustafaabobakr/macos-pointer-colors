import SwiftUI

/// The Frost pulse's one color: ice, the pair's, or a custom one picked here. The flash stays
/// white; the glow, haze and shards are shades of it.
struct FrostColorPicker: View {
    @Binding var source: FrostColorSource
    @Binding var color: RGBA
    /// The settings' defaults, for the rows' reset buttons.
    let defaultSource: FrostColorSource
    let defaultColor: RGBA

    var body: some View {
        SettingsChoice(title: Text("Color"), symbol: "paintpalette", caption: caption,
                       selection: $source.revealing(), options: FrostColorSource.allCases) { source in
            title(of: source)
        }
        .resettable($source, to: defaultSource)
        Reveal(isShown: source == .custom) {
            SettingsRow("Custom color", symbol: "eyedropper") {
                ColorPicker("Custom color", selection: Binding(get: { color.color }, set: { color = RGBA($0) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
            .resettable($color, to: defaultColor)
        }
    }

    private var caption: Text {
        switch source {
        case .ice: Text("White and icy blue.")
        case .pair: Text("Uses the brighter of the pair's outline and fill, so it follows the pair on each display.")
        case .custom: Text("Uses the color you pick.")
        }
    }

    private func title(of source: FrostColorSource) -> Text {
        switch source {
        case .ice: Text("Ice")
        case .pair: Text("Pointer pair")
        case .custom: Text("Custom")
        }
    }
}
