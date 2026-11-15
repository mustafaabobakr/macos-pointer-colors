import SwiftUI

/// A small sun and moon switch in a picture's corner. It changes the background of every effect
/// picture in Preferences at once, since they share one saved choice.
struct PreviewBackdropPicker: View {
    @AppStorage(PreviewBackdrop.key) private var backdrop = PreviewBackdrop.dark

    /// A plate just darker or lighter than the picture, so the switch stands out from it.
    private var backing: Color {
        backdrop == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.1)
    }

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
        .padding(2)
        .background(backing, in: RoundedRectangle(cornerRadius: 7))
        // In the picture's own appearance, so both icons show on a light picture in a dark window
        // and the other way round.
        .environment(\.colorScheme, backdrop == .light ? .light : .dark)
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
