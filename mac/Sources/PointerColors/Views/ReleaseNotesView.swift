import SwiftUI

/// What changed in an available update, from its release notes on GitHub. Scrolls inside a fixed
/// height, so long notes can't stretch the menu.
struct ReleaseNotesView: View {
    let version: String
    let notes: String
    let height: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("What's new in \(version)").appFont(.caption, weight: .semibold)
            ScrollView {
                Text(Self.rendered(notes))
                    .appFont(.caption)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: height)
        }
    }

    /// GitHub's Markdown with inline styles only (bold, code, links); list dashes become bullets.
    static func rendered(_ markdown: String) -> AttributedString {
        let bulleted = markdown.replacingOccurrences(of: "(?m)^- ", with: "• ", options: .regularExpression)
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: bulleted, options: options)) ?? AttributedString(markdown)
    }
}
