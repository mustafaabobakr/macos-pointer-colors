import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Preferences › Automation › Apps: a pair per app, applied while that app is in front.
struct AppColorsSection: View {
    @Bindable var automation: Automation
    let pairs: [PointerPair]

    var body: some View {
        Section {
            Toggle(isOn: $automation.perAppColors) {
                Text("Different pair for each app")
                Text("Applies while the app is in front. App pairs win over display pairs.")
            }
            ForEach(automation.appRuleIDs, id: \.self) { bundleID in
                AppColorRow(automation: automation, bundleID: bundleID, pairs: pairs)
            }
            Button("Add App…", action: addApp)
        } header: {
            Text("Apps")
        }
    }

    /// Picks an app; it starts with the first pair so it has a visible rule right away.
    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let ids = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        let firstPair = pairs.first { $0.system == nil }?.id ?? pairs.first?.id
        for id in ids where automation.pairID(forApp: id) == nil {
            automation.setPair(firstPair, forApp: id)
        }
    }
}

private struct AppColorRow: View {
    let automation: Automation
    let bundleID: String
    let pairs: [PointerPair]
    @Environment(\.appTextScale) private var scale

    private var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    private var appName: String {
        appURL.map { FileManager.default.displayName(atPath: $0.path) } ?? bundleID
    }

    var body: some View {
        HStack(spacing: 8) {
            if let appURL {
                Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
                    .resizable().frame(width: 32 * scale, height: 32 * scale).accessibilityHidden(true)
            }
            Text(appName).lineLimit(1)
            Spacer()
            PairMenuButton(selection: selection, pairs: pairs,
                           accessibilityTitle: String(localized: "Pair for \(appName)"), allowsNone: false)
            Button { automation.setPair(nil, forApp: bundleID) } label: {
                Image(systemName: "minus.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Remove \(appName)")
            .accessibilityLabel("Remove \(appName)")
        }
    }

    private var selection: Binding<String?> {
        Binding(get: { automation.pairID(forApp: bundleID) },
                set: { if let id = $0 { automation.setPair(id, forApp: bundleID) } })
    }
}
