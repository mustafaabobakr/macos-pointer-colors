import SwiftUI

/// The sidebar's search field, sized with the app's Text size (the system's search field keeps
/// one size), in glass on macOS 26 and later.
struct SidebarSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    @Environment(\.appTextScale) private var scale
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: 6 * scale) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search settings", text: $text)
                .textFieldStyle(.plain)
                .focused(isFocused)
            if !text.isEmpty {
                Button("Clear Search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .appFont(.body)
        .padding(.horizontal, 10 * scale)
        .frame(height: 30 * scale)
        .background { background }
        .overlay {
            Capsule().strokeBorder(Color.accentColor, lineWidth: 2).opacity(isFocused.wrappedValue ? 0.8 : 0)
        }
        .contentShape(Capsule())
        .onTapGesture { isFocused.wrappedValue = true }
    }

    @ViewBuilder private var background: some View {
        if #available(macOS 26, *), !reduceTransparency {
            Color.clear.glassEffect(.regular, in: Capsule())
        } else {
            Capsule().fill(.quaternary)
        }
    }
}
