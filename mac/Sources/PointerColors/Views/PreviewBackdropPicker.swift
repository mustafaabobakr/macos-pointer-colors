import SwiftUI

/// A small sun and moon switch in a picture's corner. It changes the background of every effect
/// picture in Preferences at once, since they share one saved choice.
struct PreviewBackdropPicker: View {
    @AppStorage(PreviewBackdrop.key) private var backdrop = PreviewBackdrop.dark

    var body: some View {
        Picker(selection: $backdrop) {
            ForEach(PreviewBackdrop.allCases) { option in
                Image(systemName: option.symbol)
                    .accessibilityLabel(option.label)
                    .tag(option)
            }
        } label: {
            Text("Picture background")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
        .fixedSize()
        .padding(6)
        .help(Text("Picture background"))
    }
}

extension View {
    /// Draws this picture on the saved backdrop, with the switch for it in the top left corner.
    func previewBackdropSwitch() -> some View {
        modifier(PreviewBackdropSwitch())
    }
}

private struct PreviewBackdropSwitch: ViewModifier {
    @AppStorage(PreviewBackdrop.key) private var backdrop = PreviewBackdrop.dark

    func body(content: Content) -> some View {
        content
            .environment(\.previewBackdrop, backdrop)
            .overlay(alignment: .topLeading) { PreviewBackdropPicker() }
    }
}
