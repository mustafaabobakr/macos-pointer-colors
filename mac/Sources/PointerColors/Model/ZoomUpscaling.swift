/// How the zoom enlarges the screen's picture. It can't add detail the screen didn't have; the
/// sharp choices keep edges, like text, crisper than plain smoothing.
enum ZoomUpscaling: String, CaseIterable, Identifiable {
    /// The display's own smoothing between pixels, the cheapest.
    case smooth
    /// Lanczos scaling of just the part shown, then a light sharpen.
    case sharp
    /// The same, sharpened more.
    case sharper

    var id: Self { self }

    var title: String {
        switch self {
        case .smooth: String(localized: "Smooth")
        case .sharp: String(localized: "Sharp")
        case .sharper: String(localized: "Sharper")
        }
    }

    /// How strongly edges are sharpened after scaling; nil draws no picture of its own.
    var sharpening: Double? {
        switch self {
        case .smooth: nil
        case .sharp: 0.5
        case .sharper: 1.0
        }
    }

    /// What this choice does well, from how it draws.
    var upsides: [String] {
        switch self {
        case .smooth: [String(localized: "No extra work: the display enlarges the picture itself."),
                       String(localized: "No outlines around edges, so photos and shading stay even.")]
        case .sharp: [String(localized: "Text and thin lines stay crisper."),
                      String(localized: "Sharpened lightly, so edges keep their look.")]
        case .sharper: [String(localized: "The crispest text and lines.")]
        }
    }

    /// What it costs.
    var downsides: [String] {
        switch self {
        case .smooth: [String(localized: "Text and thin lines look soft, more so the more you zoom.")]
        case .sharp: [String(localized: "Draws its own picture whenever the screen or the zoomed part changes, using more of the graphics chip while zoomed.")]
        case .sharper: [String(localized: "Thin light or dark outlines can show along edges."),
                        String(localized: "The same extra graphics work as Sharp.")]
        }
    }
}
