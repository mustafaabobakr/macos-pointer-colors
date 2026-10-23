import Foundation

/// `pointercolors://add?name=Aqua%20mint&outline=00FFDA&fill=008A59`, used by the website's
/// "Add to Mac app" button.
struct PairLink: Equatable {
    static let scheme = "pointercolors"

    let name: String
    let outline: RGBA
    let fill: RGBA

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme, url.host?.lowercased() == "add",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        let value = { (key: String) in items.first { $0.name == key }?.value }
        guard let outline = value("outline").flatMap(RGBA.init(hex:)),
              let fill = value("fill").flatMap(RGBA.init(hex:)) else { return nil }
        let trimmed = (value("name") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Cap the length: the link comes from outside the app.
        name = String((trimmed.isEmpty ? String(localized: "From the website") : trimmed).prefix(40))
        self.outline = outline
        self.fill = fill
    }
}
