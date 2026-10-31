import SwiftUI

/// Preferences › What's New: every release from the changelog, newest first.
struct WhatsNewPreferences: View {
    private let changelog = Changelog.bundled
    private static let releasesPage = URL(string: "https://github.com/mustafaabobakr/macos-pointer-colors/releases")!

    private var installedVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    var body: some View {
        SettingsPage("What's New") {
            if changelog.releases.isEmpty {
                SettingsCard {
                    SettingsRow("The changelog isn't in this build.", symbol: "doc.text") {
                        Link("Releases Page", destination: Self.releasesPage)
                    }
                }
            }
            ForEach(changelog.releases) { release in
                ReleaseCard(release: release, isInstalled: release.version == installedVersion)
                    .featureSpot(release.id == changelog.releases.first?.id ? "whats-new" : "")
            }
        }
    }
}

private struct ReleaseCard: View {
    let release: Changelog.Release
    let isInstalled: Bool
    @Environment(\.appTextScale) private var scale

    var body: some View {
        SettingsCard {
            HStack(alignment: .firstTextBaseline, spacing: 8 * scale) {
                Text(verbatim: release.version).appFont(.title3, weight: .bold)
                if isInstalled {
                    Text("This version")
                        .appFont(.caption2, weight: .bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6 * scale)
                        .padding(.vertical, 2 * scale)
                        .background(Capsule().fill(Color.accentColor))
                }
                Spacer()
                if let date = release.date {
                    Text(verbatim: date).appFont(.caption, monospacedDigits: true).foregroundStyle(.secondary)
                }
            }
            ForEach(Array(release.lines.enumerated()), id: \.offset) { _, line in
                ReleaseLine(line: line)
            }
        }
    }
}

private struct ReleaseLine: View {
    let line: Changelog.Line
    @Environment(\.appTextScale) private var scale

    var body: some View {
        switch line {
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 9 * scale) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .accessibilityHidden(true)
                markdown(text)
            }
        case .paragraph(let text):
            markdown(text).foregroundStyle(.secondary)
        }
    }

    private func markdown(_ text: String) -> some View {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let attributed = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        return Text(attributed)
            .appFont(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }
}
