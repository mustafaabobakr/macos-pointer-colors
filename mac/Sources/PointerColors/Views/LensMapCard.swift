import SwiftUI

/// One choice of a lens setting as a card: a map of a display to move the pointer over, what the
/// choice does, and what it does well and what it costs. The chosen one is outlined.
struct LensMapCard: View {
    let title: String
    let summary: String
    let upsides: [String]
    let downsides: [String]
    let isDefault: Bool
    let isSelected: Bool
    let map: LensPlacementMap
    let select: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8 * scale) {
                LensMapDemo(map: map)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
                heading
                Text(summary).appFont(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4 * scale) {
                    ForEach(upsides, id: \.self) { UpsideDownsidePoint(text: $0, isUpside: true) }
                    ForEach(downsides, id: \.self) { UpsideDownsidePoint(text: $0, isUpside: false) }
                }
            }
            .padding(8 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2.5 : 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var heading: some View {
        HStack(spacing: 4 * scale) {
            Text(title)
                .appFont(.callout, weight: .semibold)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
            if isDefault {
                Text("Default").appFont(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// The cards' grid: as many columns as fit, each at least 220 points wide before Text size.
struct LensMapCardGrid<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.appTextScale) private var scale

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220 * scale), spacing: 10 * scale, alignment: .top)],
                  alignment: .leading, spacing: 10 * scale) {
            content
        }
    }
}

/// The map, following the pointer while it's over it.
private struct LensMapDemo: View {
    let map: LensPlacementMap
    @State private var pointer: CGPoint?
    @State private var size = CGSize.zero
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let shownPointer = pointer ?? map.startPointer
        Canvas { [map] context, size in
            map.draw(in: context, size: size, pointer: shownPointer, dark: dark)
        }
        .aspectRatio(LensPlacementMap.screen.width / LensPlacementMap.screen.height, contentMode: .fit)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .onContinuousHover { phase in
            guard case .active(let location) = phase, size.width > 0 else { return }
            pointer = CGPoint(x: location.x / size.width * LensPlacementMap.screen.width,
                              y: location.y / size.height * LensPlacementMap.screen.height)
        }
        .accessibilityHidden(true)
    }
}
