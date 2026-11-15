/// Where Smart zoom's lens sits relative to the pointer. Whichever it is, the lens shows the area
/// around the pointer; only the lens itself moves.
enum LensPlacement: String, CaseIterable, Identifiable {
    /// Centred on the pointer, as the lens has always been.
    case onPointer
    /// Always diagonal, toward the half of the screen with more room.
    case quadrants
    /// Straight above, diagonal only in a band along each side.
    case edgeBands
    /// Straight above, sliding along the screen's edges.
    case slideAndFlip
    /// Circles the pointer toward open space, with no zones.
    case orbit

    var id: Self { self }

    var title: String {
        switch self {
        case .onPointer: String(localized: "On the pointer")
        case .quadrants: String(localized: "Quadrants")
        case .edgeBands: String(localized: "Edge bands")
        case .slideAndFlip: String(localized: "Slide and flip")
        case .orbit: String(localized: "Orbit")
        }
    }

    var summary: String {
        switch self {
        case .onPointer: String(localized: "The lens sits centred on the pointer and magnifies what's right under it.")
        case .quadrants: String(localized: "The lens is always diagonal, on the side of the screen with more room: pointer in the right half → lens up-left, left half → up-right. Near the top it drops below.")
        case .edgeBands: String(localized: "Straight above in open space. Only in a band along each side, as wide as half the lens, it moves diagonally away from that edge. Near the top it drops below.")
        case .slideAndFlip: String(localized: "Always straight above, but it slides along the screen edge instead of going past it. It only jumps once: below, when there's no room above.")
        case .orbit: String(localized: "The lens circles around the pointer, leaning toward the middle of the screen, and turns smoothly from above to beside to below as you near the top. No zones at all.")
        }
    }

    var upsides: [String] {
        switch self {
        case .onPointer: [String(localized: "What you look at is exactly where you point"), String(localized: "Never moves away from the pointer")]
        case .quadrants: [String(localized: "Corners put the lens on the side with room"), String(localized: "4 zones, easy to predict")]
        case .edgeBands: [String(localized: "Straight above most of the time"), String(localized: "Corners behave like Quadrants")]
        case .slideAndFlip: [String(localized: "No sideways jumps at all, only one flip"), String(localized: "Smooth along the side edges")]
        case .orbit: [String(localized: "No jumps anywhere, every move is smooth"), String(localized: "Always finds the open space")]
        }
    }

    var downsides: [String] {
        switch self {
        case .onPointer: [String(localized: "Covers the pointer and what's around it")]
        case .quadrants: [String(localized: "Jumps sides when crossing the middle of the screen"), String(localized: "Never straight above, even in open space")]
        case .edgeBands: [String(localized: "6 zones, so 2 more boundaries to jump at"), String(localized: "Bands grow with the lens width")]
        case .slideAndFlip: [String(localized: "In a corner the pointer sits under the lens's edge, not beside it")]
        case .orbit: [String(localized: "Rarely exactly above; the angle keeps changing"), String(localized: "Harder to predict where it will be")]
        }
    }
}
