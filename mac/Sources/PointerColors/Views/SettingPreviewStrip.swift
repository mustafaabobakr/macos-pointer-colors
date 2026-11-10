import SwiftUI

/// One choice of a setting, pictured: its label, the settings it draws with, and whether it's the
/// one chosen now.
struct SettingPreviewCase {
    let label: String
    let sample: HighlightPreviewSample
    let isCurrent: Bool
}

/// A setting's choices side by side, each a picture with its label inside, the chosen one outlined.
struct SettingPreviewStrip: View {
    let scene: HighlightPreviewScene
    let pair: PointerPair
    let cases: [SettingPreviewCase]

    /// How much larger than the cards on the page each picture is drawn.
    private static let zoom: CGFloat = 1.8

    var body: some View {
        HStack(spacing: 12) {
            ForEach(cases.indices, id: \.self) { tile(cases[$0]) }
        }
        .accessibilityElement(children: .combine)
    }

    private func tile(_ item: SettingPreviewCase) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HighlightPreviewImage(scene: scene, pair: pair, sample: item.sample, zoom: Self.zoom)
            .frame(width: 132 * Self.zoom, height: 88 * Self.zoom)
            .clipShape(shape)
            .overlay(alignment: .bottom) { label(item) }
            .overlay {
                shape.strokeBorder(item.isCurrent ? Color.accentColor : .white.opacity(0.15),
                                   lineWidth: item.isCurrent ? 2 : 1)
            }
            .accessibilityLabel(item.label)
            .accessibilityAddTraits(item.isCurrent ? .isSelected : [])
    }

    private func label(_ item: SettingPreviewCase) -> some View {
        HStack(spacing: 4) {
            if item.isCurrent { Image(systemName: "checkmark").font(.callout.weight(.bold)) }
            Text(item.label)
        }
        .appFont(.body, weight: item.isCurrent ? .semibold : .regular)
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(.bottom, 10)
    }
}
