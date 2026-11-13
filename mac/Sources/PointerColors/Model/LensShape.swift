import CoreGraphics

/// The outline of Smart zoom's lens.
enum LensShape: String, CaseIterable, Identifiable {
    /// Wide like a screen, 16:9, for lines of text.
    case rectangle
    case square
    case circle

    var id: Self { self }

    var title: String {
        switch self {
        case .rectangle: String(localized: "Rectangle")
        case .square: String(localized: "Square")
        case .circle: String(localized: "Circle")
        }
    }

    /// The lens's size when it's `width` points wide.
    func size(width: CGFloat) -> CGSize {
        CGSize(width: width, height: self == .rectangle ? width * 9 / 16 : width)
    }

    /// The corner radius that gives a lens `size` this shape.
    func cornerRadius(for size: CGSize) -> CGFloat {
        self == .circle ? min(size.width, size.height) / 2 : 0
    }
}
