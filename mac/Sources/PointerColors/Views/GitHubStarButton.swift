import AppKit
import SwiftUI

/// "Star on GitHub" with GitHub's mark and the repository's star count, as on the website. It's
/// About's main button, so it's filled.
struct GitHubStarButton: View {
    static let repository = URL(string: "https://github.com/mustafaabobakr/macos-pointer-colors")!

    @State private var stars: Int?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Link(destination: Self.repository) {
            HStack(spacing: 8 * scale) {
                if let mark = GitHubMark.image {
                    Image(nsImage: mark)
                        .resizable()
                        .frame(width: 16 * scale, height: 16 * scale)
                        .accessibilityHidden(true)
                }
                Text("Star on GitHub")
                if let stars { StarCount(count: stars) }
            }
            .padding(.trailing, stars == nil ? 0 : -6 * scale)
        }
        .buttonStyle(AboutLinkStyle(isPrimary: true))
        .accessibilityLabel(stars.map { Text("Star on GitHub, \($0) stars") } ?? Text("Star on GitHub"))
        .help(Self.repository.absoluteString)
        .task { stars = await GitHubStars.count() }
    }
}

/// The website, next to the GitHub button and drawn as its quieter partner.
struct WebsiteButton: View {
    static let website = URL(string: "https://macos-pointer-colors.pages.dev")!
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Link(destination: Self.website) {
            HStack(spacing: 8 * scale) {
                Image(systemName: "globe")
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .accessibilityHidden(true)
                Text("Website")
            }
        }
        .buttonStyle(AboutLinkStyle(isPrimary: false))
        .help(Self.website.absoluteString)
    }
}

/// About's link buttons: the same shape as the website's, filled for the main one and outlined
/// for the other. The fill is the text color, so it reads dark in Light and light in Dark.
private struct AboutLinkStyle: ButtonStyle {
    let isPrimary: Bool
    @Environment(\.appTextScale) private var scale

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
        configuration.label
            .appFont(.callout, weight: .semibold)
            .foregroundStyle(isPrimary ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.primary))
            .padding(.horizontal, 12 * scale)
            .frame(minHeight: 34 * scale)
            .background(isPrimary ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.primary.opacity(0.06)), in: shape)
            .overlay { shape.strokeBorder(Color.primary.opacity(isPrimary ? 0 : 0.14)) }
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// The star and count, in a pill of its own at the button's end.
private struct StarCount: View {
    let count: Int
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 4 * scale) {
            Image(systemName: "star.fill")
                .font(.system(size: 11 * scale))
                .foregroundStyle(Color(red: 0.89, green: 0.70, blue: 0.25))
            Text(count.formatted(.number.notation(.compactName)))
                .monospacedDigit()
        }
        .padding(.horizontal, 8 * scale)
        .padding(.vertical, 3 * scale)
        .background(.foreground.opacity(0.16), in: RoundedRectangle(cornerRadius: 7 * scale, style: .continuous))
    }
}

/// GitHub's mark, the same drawing the website uses, tinted to match the text.
private enum GitHubMark {
    static let image: NSImage? = {
        let svg = """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><path fill="#000" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>
            """
        let image = NSImage(data: Data(svg.utf8))
        image?.isTemplate = true
        return image
    }()
}

/// The repository's star count from GitHub, kept for an hour so Preferences doesn't ask on every visit.
@MainActor
enum GitHubStars {
    static let defaultsKey = "githubStars"
    private static let api = URL(string: "https://api.github.com/repos/mustafaabobakr/macos-pointer-colors")!
    private static let freshFor: TimeInterval = 3600

    private struct Repository: Decodable {
        let stargazers_count: Int
    }

    /// The count, or nil when GitHub can't be reached and none is saved.
    static func count() async -> Int? {
        let saved = UserDefaults.standard.dictionary(forKey: defaultsKey)
        let savedCount = saved?["count"] as? Int
        if let savedCount, let date = saved?["date"] as? Date, Date().timeIntervalSince(date) < freshFor {
            return savedCount
        }
        guard let (data, response) = try? await URLSession.shared.data(from: api),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let repository = try? JSONDecoder().decode(Repository.self, from: data) else { return savedCount }
        UserDefaults.standard.set(["count": repository.stargazers_count, "date": Date()], forKey: defaultsKey)
        return repository.stargazers_count
    }
}
