import SwiftUI

/// A color control that stays inside the menu-bar popover: a hex field plus quick swatches.
/// SwiftUI's ColorPicker opens the system color panel, which takes focus and closes the popover.
struct InlineColorField: View {
    let label: LocalizedStringKey
    @Binding var color: RGBA
    @State private var text = ""
    @Environment(\.appTextScale) private var scale

    private static let swatches = ["FFFFFF", "000000", "FF453A", "FF9F0A", "FFD60A", "30D158",
                                   "00FFDA", "64D2FF", "0A84FF", "5B21B6", "FF4FD8", "8E8E93"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label).appFont(.caption).frame(width: 52 * scale, alignment: .leading)
                RoundedRectangle(cornerRadius: 4).fill(color.color)
                    .frame(width: 18 * scale, height: 18 * scale)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.5)))
                TextField("RRGGBB", text: $text)
                    .appFont(.caption, monospacedDigits: true)
                    .frame(width: 80 * scale)
                    .onSubmit(commit)
                    .onChange(of: text) { if text.count == 6 || text.count == 7 { commit() } }
            }
            HStack(spacing: 3) {
                ForEach(Self.swatches, id: \.self) { hex in
                    Button { color = RGBA(hex: hex)!; text = hex } label: {
                        Circle().fill(RGBA(hex: hex)!.color)
                            .frame(width: 14 * scale, height: 14 * scale)
                            .overlay(Circle().strokeBorder(color.hex == hex ? Color.accentColor : .secondary.opacity(0.4),
                                                           lineWidth: color.hex == hex ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("#\(hex)")
                }
            }
        }
        .onAppear { text = color.hex }
    }

    private func commit() {
        guard let parsed = RGBA(hex: text.trimmingCharacters(in: .whitespaces)) else { return }
        color = parsed
    }
}
