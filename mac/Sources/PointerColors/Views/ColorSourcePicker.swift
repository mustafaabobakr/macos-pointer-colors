import SwiftUI

/// The pair's colors, or a custom color picked here.
struct ColorSourcePicker: View {
    @Binding var usesPair: Bool
    @Binding var color: RGBA

    var body: some View {
        SettingsMenu(title: Text("Color"), symbol: "paintpalette",
                     caption: usesPair ? Text("Uses the pair's color, set for each pair in Pair colors.") : Text("Uses the color you pick."),
                     selection: $usesPair) {
            Text("Pointer pair").tag(true)
            Text("Custom").tag(false)
        }
        if !usesPair {
            SettingsRow("Custom color", symbol: "eyedropper") {
                ColorPicker("Custom color", selection: Binding(get: { color.color }, set: { color = RGBA($0) }),
                            supportsOpacity: false)
                    .labelsHidden()
            }
        }
    }
}
