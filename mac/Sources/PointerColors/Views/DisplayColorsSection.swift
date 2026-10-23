import SwiftUI

/// "Separate colors for each display": the grid pair is the default for every display, and each
/// display can override it with its own pair.
struct DisplayColorsSection: View {
    @Bindable var automation: Automation
    let pairs: [PointerPair]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Separate colors for each display", isOn: $automation.perDisplayColors)
                .toggleStyle(.checkbox)
                .appFont(.caption)
            if automation.perDisplayColors {
                Text("The pair above is the default for all displays.")
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(automation.displays) { display in
                    DisplayColorRow(automation: automation, display: display, pairs: pairs,
                                    isCurrent: display.id == automation.lastDisplayID)
                }
            }
        }
    }
}

private struct DisplayColorRow: View {
    let automation: Automation
    let display: DisplayInfo
    let pairs: [PointerPair]
    let isCurrent: Bool
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                .frame(width: 20 * scale, alignment: .center)
                .accessibilityHidden(true)
            Text(display.name).appFont(.caption).lineLimit(1).truncationMode(.middle)
            if isCurrent {
                Text("(current)").appFont(.caption, weight: .semibold).foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 8)
            PairMenuButton(selection: selection, pairs: pairs,
                           accessibilityTitle: String(localized: "Colors on \(display.name)"))
        }
    }

    private var selection: Binding<String?> {
        Binding(get: { automation.pairID(for: display) },
                set: { automation.setPair($0, for: display) })
    }
}

/// A pop-up list of pairs, each with a pointer preview. Built from the live pair list on every
/// open, so new custom pairs show up, and it follows the app's Text size setting.
/// Shared by the per-display rows in the menu and the per-app rows in Preferences.
struct PairMenuButton: View {
    @Binding var selection: String?
    let pairs: [PointerPair]
    let accessibilityTitle: String
    /// Offers "Same as all displays" (a nil selection) at the top.
    var allowsNone = true
    @State private var isOpen = false
    @Environment(\.appTextScale) private var scale

    private var selectedPair: PointerPair? { pairs.first { $0.id == selection } }

    var body: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 6) {
                if let pair = selectedPair { PointerGlyph(pair: pair).frame(height: 16 * scale) }
                Text(selectedPair?.name ?? String(localized: "Same as all displays")).appFont(.caption).lineLimit(1)
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
                Text(pair?.name ?? String(localized: "Same as all displays")).appFont(.body).lineLimit(1)
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
