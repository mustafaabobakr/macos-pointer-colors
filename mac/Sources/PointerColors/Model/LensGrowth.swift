import CoreGraphics

/// Where Smart zoom's lens grows out of as it zooms in, and shrinks back into as it zooms out.
enum LensGrowth: String, CaseIterable, Identifiable {
    /// The lens's point nearest the pointer, which stays put as it grows.
    case nearestEdge
    /// The pointer itself: the lens flies out from it to where it sits.
    case pointer
    /// The lens's own middle: it grows in place.
    case lensCentre

    var id: Self { self }

    var title: String {
        switch self {
        case .nearestEdge: String(localized: "Nearest edge")
        case .pointer: String(localized: "Pointer")
        case .lensCentre: String(localized: "Lens centre")
        }
    }

    /// The lens's frame `grown` of the way (0 to 1) from its start to `lens`, all in points.
    func frame(_ grown: Double, lens: CGRect, pointer: CGPoint) -> CGRect {
        let start = startPoint(lens: lens, pointer: pointer)
        let part = CGFloat(grown)
        return CGRect(x: start.x + (lens.minX - start.x) * part, y: start.y + (lens.minY - start.y) * part,
                      width: lens.width * part, height: lens.height * part)
    }

    private func startPoint(lens: CGRect, pointer: CGPoint) -> CGPoint {
        switch self {
        case .nearestEdge: CGPoint(x: min(max(pointer.x, lens.minX), lens.maxX), y: min(max(pointer.y, lens.minY), lens.maxY))
        case .pointer: pointer
        case .lensCentre: CGPoint(x: lens.midX, y: lens.midY)
        }
    }
}
