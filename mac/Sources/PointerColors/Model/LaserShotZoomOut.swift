/// Which Magic Mouse zooms end once a laser screenshot is taken.
enum LaserShotZoomOut: String, CaseIterable, Identifiable {
    case off
    case wholeScreen
    case lens
    case both

    var id: Self { self }

    var title: String {
        switch self {
        case .off: String(localized: "Off")
        case .wholeScreen: String(localized: "Whole screen")
        case .lens: String(localized: "Lens")
        case .both: String(localized: "Both")
        }
    }

    /// Whether a zoom of `style` ends after the screenshot.
    func endsZoom(_ style: ZoomStyle) -> Bool {
        switch self {
        case .off: false
        case .both: true
        case .wholeScreen: style == .wholeScreen
        case .lens: style == .lens
        }
    }
}
