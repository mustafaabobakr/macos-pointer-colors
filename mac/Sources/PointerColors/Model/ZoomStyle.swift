/// How Smart zoom magnifies: the whole display, or a lens that follows the pointer.
enum ZoomStyle: String, CaseIterable, Identifiable {
    case wholeScreen
    case lens

    var id: Self { self }

    var title: String {
        switch self {
        case .wholeScreen: String(localized: "Whole screen")
        case .lens: String(localized: "Lens")
        }
    }
}
