import SwiftUI

/// Smooth, Sharp and Sharper as cards side by side: each with a sample enlarged that way at the
/// zoom amount, and what it does well and what it costs. The chosen one is outlined.
struct ZoomUpscalingPicker: View {
    @Binding var selection: ZoomUpscaling
    let amount: Double
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(alignment: .top, spacing: 10 * scale) {
            ForEach(ZoomUpscaling.allCases) { option in
                UpscalingCard(option: option, amount: amount, isSelected: selection == option) { selection = option }
            }
        }
    }
}

private struct UpscalingCard: View {
    let option: ZoomUpscaling
    let amount: Double
    let isSelected: Bool
    let select: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 8 * scale) {
                UpscalingSamplePicture(option: option, amount: amount)
                    .frame(height: 64 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 6 * scale))
                title
                VStack(alignment: .leading, spacing: 4 * scale) {
                    ForEach(option.upsides, id: \.self) { Point(text: $0, isUpside: true) }
                    ForEach(option.downsides, id: \.self) { Point(text: $0, isUpside: false) }
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

    private var title: some View {
        HStack(spacing: 4 * scale) {
            Text(option.title)
                .appFont(.callout, weight: .semibold)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
            if option == .smooth {
                Text("Default").appFont(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// One upside or downside, marked with a plus or a minus.
private struct Point: View {
    let text: String
    let isUpside: Bool
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4 * scale) {
            Image(systemName: isUpside ? "plus.circle.fill" : "minus.circle.fill")
                .foregroundStyle(isUpside ? .green : .orange)
                .accessibilityLabel(isUpside ? Text("Upside") : Text("Downside"))
            Text(text).appFont(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appFont(.caption)
    }
}

/// The sample, drawn for its real size on this display so it shows what the zoom would.
private struct UpscalingSamplePicture: View {
    let option: ZoomUpscaling
    let amount: Double
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            if let picture = ZoomUpscalingSample.picture(option, size: proxy.size, amount: amount, scale: displayScale,
                                                         dark: colorScheme == .dark) {
                Image(decorative: picture, scale: displayScale).interpolation(.none)
            }
        }
        .accessibilityHidden(true)
    }
}
