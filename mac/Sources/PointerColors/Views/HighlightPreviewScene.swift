/// What a highlight picture shows: one of the effects, or the ring around a still pointer.
enum HighlightPreviewScene {
    case ring
    case pulse
    case laser
    case press

    init(_ effect: HighlightEffect) {
        switch effect {
        case .pulse: self = .pulse
        case .laser: self = .laser
        case .press: self = .press
        }
    }
}

/// The settings one picture is drawn with: the overlay's style plus what only the pictures vary.
struct HighlightPreviewSample {
    var style: HighlightStyle
    var pressScale: Double
    /// The laser picture draws its trail.
    var showsTrail = true
    /// The laser picture draws the dot; with no trail it sits under a moving pointer.
    var showsDot = true
    /// Draws the press at its real size. Off, it's drawn at least 0.7× so it reads in a small picture.
    var exactPress = false
}
