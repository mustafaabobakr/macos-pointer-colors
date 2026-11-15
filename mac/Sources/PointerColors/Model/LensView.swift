import CoreGraphics

/// Which part of the display Smart zoom's lens magnifies, relative to the pointer and the lens.
enum LensView: String, CaseIterable, Identifiable {
    /// The pointer in the middle of the picture, as the lens has always shown it.
    case centred
    /// The picture stretches from the pointer toward where the lens sits.
    case towardLens
    /// A magnifying glass: what the lens itself covers.
    case underLens
    /// The pointer's tip at a spot set by `MagicMouseZoom.lensViewSpot`.
    case pointerSpot

    var id: Self { self }

    var title: String {
        switch self {
        case .centred: String(localized: "Centred")
        case .towardLens: String(localized: "Toward the lens")
        case .underLens: String(localized: "Under the lens")
        case .pointerSpot: String(localized: "Pointer at a spot")
        }
    }

    var summary: String {
        switch self {
        case .centred: String(localized: "The pointer sits in the middle of the magnified picture.")
        case .towardLens: String(localized: "The picture stretches from the pointer toward the lens: with the lens up-left, the pointer shows near the picture's bottom right.")
        case .underLens: String(localized: "Like a magnifying glass: the lens shows what's under the lens itself, not around the pointer.")
        case .pointerSpot: String(localized: "The pointer's tip sits at the spot set by Pointer spot, measured from the picture's top left.")
        }
    }

    var upsides: [String] {
        switch self {
        case .centred: [String(localized: "Shows as much on every side of the pointer")]
        case .towardLens: [String(localized: "The pointer in the picture is on the same side as the real one"), String(localized: "More of what lies between the pointer and the lens")]
        case .underLens: [String(localized: "What the lens covers is still visible, magnified")]
        case .pointerSpot: [String(localized: "More of what's right of and below the arrow tip, where text reads"), String(localized: "The same spot every time")]
        }
    }

    var downsides: [String] {
        switch self {
        case .centred: [String(localized: "With the lens beside the pointer, half the picture is the side away from the lens")]
        case .towardLens: [String(localized: "The pointer moves across the picture when the lens changes sides")]
        case .underLens: [String(localized: "The pointer isn't in the picture when the lens is beside it"), String(localized: "You aim the lens, not the pointer, at what you want to read")]
        case .pointerSpot: [String(localized: "Ignores which side the lens is on")]
        }
    }

    /// The part of the display the lens shows, in points from the display's top left, for the lens at
    /// `lens` magnifying `amount` times. `spot` is Pointer spot's fraction of the picture.
    func shownArea(pointer: CGPoint, lens: CGRect, amount: Double, spot: Double) -> CGRect {
        let size = CGSize(width: lens.width / amount, height: lens.height / amount)
        let focus = self == .underLens ? CGPoint(x: lens.midX, y: lens.midY) : pointer
        let anchor = anchor(pointer: pointer, lens: lens, spot: spot)
        return CGRect(origin: CGPoint(x: focus.x - anchor.x * size.width, y: focus.y - anchor.y * size.height), size: size)
    }

    /// Where the focus shows in the picture, as fractions of its width and height from the top left.
    private func anchor(pointer: CGPoint, lens: CGRect, spot: Double) -> CGPoint {
        switch self {
        case .centred, .underLens:
            return CGPoint(x: 0.5, y: 0.5)
        case .pointerSpot:
            return CGPoint(x: spot, y: spot)
        case .towardLens:
            guard lens.width > 0, lens.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
            let along = { (value: CGFloat) in min(max(value, Self.towardLensInset), 1 - Self.towardLensInset) }
            return CGPoint(x: along((pointer.x - lens.minX) / lens.width), y: along((pointer.y - lens.minY) / lens.height))
        }
    }

    /// How far in from the picture's edges Toward the lens keeps the pointer, as a fraction, so its
    /// arrow stays in view.
    static let towardLensInset: CGFloat = 0.1
}
