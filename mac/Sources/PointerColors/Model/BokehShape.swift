/// The shapes a Bokeh click's squares form: always evenly around the click, starting straight to
/// the right, as on every click of the reference clip.
enum BokehShape: String, CaseIterable, Identifiable {
    case pentagon
    case cross
    case triangle
    case pair

    var id: String { rawValue }

    /// How many squares fly out.
    var count: Int {
        switch self {
        case .pentagon: 5
        case .cross: 4
        case .triangle: 3
        case .pair: 2
        }
    }

    var title: String {
        switch self {
        case .pentagon: String(localized: "Pentagon")
        case .cross: String(localized: "Cross")
        case .triangle: String(localized: "Triangle")
        case .pair: String(localized: "Pair")
        }
    }

    /// One line under its card: what it is and how often the clip shows it.
    var summary: String {
        switch self {
        case .pentagon: String(localized: "5 squares. 3 in 4 clicks in the clip.")
        case .cross: String(localized: "4 squares, up, down, left and right. About 1 in 9 clicks.")
        case .triangle: String(localized: "3 squares. About 1 in 15 clicks.")
        case .pair: String(localized: "2 squares, left and right. About 1 in 15 clicks.")
        }
    }
}

/// Which shapes Bokeh's clicks use.
enum BokehShapeChoice: String, CaseIterable, Identifiable {
    /// Every shape, as often as the clip shows each.
    case all
    /// Only the shapes picked on their cards, each as likely as the others.
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: String(localized: "All")
        case .custom: String(localized: "Custom")
        }
    }
}
