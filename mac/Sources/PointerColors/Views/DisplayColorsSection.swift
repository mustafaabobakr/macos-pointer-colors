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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display").accessibilityHidden(true)
            Text(display.name).appFont(.caption).lineLimit(1)
            if isCurrent {
                Text("(current)").appFont(.caption, weight: .semibold).foregroundStyle(Color.accentColor)
            }
            Spacer(minLength: 8)
            Picker(selection: selection) {
                Text("Same as all displays").tag(String?.none)
                Divider()
                ForEach(pairs) { pair in
                    Text(pair.name).tag(String?.some(pair.id))
                }
            } label: {
                Text("Colors on \(display.name)")
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var selection: Binding<String?> {
        Binding(get: { automation.pairID(for: display) },
                set: { automation.setPair($0, for: display) })
    }
}
