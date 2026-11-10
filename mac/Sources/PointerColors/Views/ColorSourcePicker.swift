import SwiftUI

/// The pair's colors, or a custom color picked here. The pair's follows whichever pair the pointer
/// shows, so each display with a pair of its own draws in that pair's color.
struct ColorSourcePicker: View {
    @Binding var usesPair: Bool
    @Binding var color: RGBA

    var body: some View {
        SettingsMenu(title: Text("Color"), symbol: "paintpalette",
                     caption: usesPair ? Text("Uses the brighter of the pair's outline and fill, so it follows the pair on each display.") : Text("Uses the color you pick."),
                     selection: $usesPair.revealing()) {
            Text("Pointer pair").tag(true)
            Text("Custom").tag(false)
        }
        Reveal(isShown: !usesPair) {
            SettingsRow("Custom color", symbol: "eyedropper") {
                ColorPicker("Custom color", selection: Binding(get: { color.color }, set: { color = RGBA($0) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }
}
