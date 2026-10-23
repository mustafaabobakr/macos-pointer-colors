import AppKit
import SwiftUI

/// Menu row shown once any app has its own pair: a checkbox to switch per-app pairs on or off,
/// and up to three overlapping app icons plus "+N" for the rest.
struct AppColorsIndicator: View {
    @Bindable var automation: Automation
    @Environment(\.appTextScale) private var scale
    @Environment(\.openSettings) private var openSettings

    private static let visibleIcons = 3

    var body: some View {
        if !automation.appRuleIDs.isEmpty {
            HStack(spacing: 8) {
                Toggle("Different pair for each app", isOn: $automation.perAppColors)
                    .toggleStyle(.checkbox)
                    .appFont(.caption)
                Spacer(minLength: 4)
                Button(action: showPreferences) { iconStack }
                    .buttonStyle(.plain)
                    .help("Edit app pairs in Preferences › Automation")
                    .accessibilityLabel("Apps with their own pair: \(automation.appRuleIDs.count)")
            }
        }
    }

    private var iconStack: some View {
        let ids = automation.appRuleIDs
        let extra = ids.count - Self.visibleIcons
        return HStack(spacing: -8 * scale) {
            ForEach(ids.prefix(Self.visibleIcons), id: \.self) { id in
                AppIcon(bundleID: id)
                    .frame(width: 22 * scale, height: 22 * scale)
                    .opacity(automation.perAppColors ? 1 : 0.45)
            }
            if extra > 0 {
                Text("+\(extra)")
                    .appFont(.caption2, weight: .semibold)
                    .padding(.horizontal, 5)
                    .frame(height: 18 * scale)
                    .background(Capsule().fill(.quaternary))
                    .padding(.leading, 12 * scale)
            }
        }
    }

    private func showPreferences() {
        NSApp.activate()
        openSettings()
    }
}

private struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        } else {
            Image(systemName: "app.dashed").resizable().scaledToFit().foregroundStyle(.secondary)
        }
    }
}
