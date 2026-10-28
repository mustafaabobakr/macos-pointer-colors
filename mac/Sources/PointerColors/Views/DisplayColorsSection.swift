import SwiftUI

/// "Separate colors for each display": the grid pair is the default for every display, and each
/// display can override it with its own pair.
struct DisplayColorsSection: View {
    @Bindable var automation: Automation
    let pairs: [PointerPair]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Separate colors for each display", isOn: $automation.perDisplayColors)
                .toggleStyle(.switch).controlSize(.mini)
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
        .featureSpot("clip-display-\(display.id)")
    }

    private var selection: Binding<String?> {
        Binding(get: { automation.pairID(for: display) },
                set: { automation.setPair($0, for: display) })
    }
}
