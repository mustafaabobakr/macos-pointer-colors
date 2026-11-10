import SwiftUI

extension EnvironmentValues {
    /// Rows with a hover preview show it. Off leaves them plain.
    @Entry var showsSettingPreviews = false
}

extension View {
    /// Shows `preview` in a popover under this row after the pointer rests on it for a moment,
    /// while the environment's `showsSettingPreviews` is on.
    func hoverPreview(@ViewBuilder _ preview: @escaping () -> some View) -> some View {
        modifier(SettingHoverPreview(preview: preview))
    }
}

/// Opens the popover once hovering has lasted `delay`, and closes it when the pointer leaves.
private struct SettingHoverPreview<Preview: View>: ViewModifier {
    let preview: () -> Preview
    @Environment(\.showsSettingPreviews) private var isEnabled
    @State private var isHovering = false
    @State private var isShown = false

    private static var delay: Duration { .milliseconds(500) }

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .task(id: isHovering && isEnabled) { await follow(hovering: isHovering && isEnabled) }
            .popover(isPresented: $isShown, arrowEdge: .bottom) {
                preview().padding(10)
            }
    }

    private func follow(hovering: Bool) async {
        guard hovering else {
            isShown = false
            return
        }
        try? await Task.sleep(for: Self.delay)
        guard !Task.isCancelled else { return }
        isShown = true
    }
}
