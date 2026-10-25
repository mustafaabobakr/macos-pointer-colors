import SwiftUI

/// The app's one pair menu: a pop-up list of pairs, each with a pointer preview. Built from the
/// live pair list on every open, so new custom pairs show up, and it follows the app's Text size
/// setting. Used for display pairs in the menu, and for app, appearance and highlight colors in
/// Preferences.
struct PairMenuButton: View {
    @Binding var selection: String?
    let pairs: [PointerPair]
    let accessibilityTitle: String
    /// Offers `noneTitle` (a nil selection) at the top.
    var allowsNone = true
    var noneTitle = String(localized: "Same as all displays")
    @State private var isOpen = false
    @Environment(\.appTextScale) private var scale

    private var selectedPair: PointerPair? { pairs.first { $0.id == selection } }

    var body: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                if let pair = selectedPair { PointerGlyph(pair: pair).frame(height: 16 * scale) }
                Text(selectedPair?.name ?? noneTitle).appFont(.caption).lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: "chevron.up.chevron.down").appFont(.caption2).foregroundStyle(.secondary)
            }
            // Fixed size, so picking a longer or shorter pair name never shifts the row.
            .frame(width: 150 * scale, height: 20 * scale)
        }
        .accessibilityLabel(accessibilityTitle)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if allowsNone {
                        row(nil)
                        Divider().padding(.vertical, 2)
                    }
                    ForEach(pairs) { row($0) }
                }
                .padding(6)
            }
            .frame(width: 220 * scale)
            .frame(maxHeight: 360 * scale)
            .appTextScale(scale)
            .liquidGlass()
        }
    }

    private func row(_ pair: PointerPair?) -> some View {
        let isSelected = pair?.id == selection
        return Button {
            selection = pair?.id
            isOpen = false
        } label: {
            HStack(spacing: 8) {
                Group {
                    if let pair { PointerGlyph(pair: pair) } else { Image(systemName: "rectangle.on.rectangle") }
                }
                .frame(width: 18 * scale, height: 20 * scale)
                Text(pair?.name ?? noneTitle).appFont(.body).lineLimit(1)
                Spacer(minLength: 4)
                if isSelected { Image(systemName: "checkmark").appFont(.caption, weight: .semibold) }
            }
            .padding(.horizontal, 6)
            .frame(minHeight: 26 * scale)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor.opacity(0.18) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    /// Liquid Glass on macOS 26 and later; the standard popover material before that.
    @ViewBuilder func liquidGlass() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 12))
                .presentationBackground(.clear)
        } else {
            self
        }
    }
}
