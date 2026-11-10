import SwiftUI

/// A small key cap that is filled with the accent color while on and plain while off, so the
/// state reads the same in an active or inactive window, unlike the system button toggle.
struct KeyToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            configuration.label
                .font(.body.weight(.semibold))
                .frame(minWidth: 28, minHeight: 22)
                .foregroundStyle(configuration.isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                .background(configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                            in: .rect(cornerRadius: 6))
                .contentShape(.rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
