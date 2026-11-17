/// Where Bokeh takes its colors from. The middle square and every flying square are shades of it.
enum BokehColorSource: String, CaseIterable, Identifiable {
    /// Golden hour: the clip's own orange to pale gold. Saved as "clip" from before it had its name.
    case clip
    /// The pair's colors, following the pair on each display.
    case pair
    /// The color picked in Preferences.
    case custom

    var id: String { rawValue }
}

/// How Bokeh turns the pair's or the custom color into its squares' colors.
enum BokehColorLook: String, CaseIterable, Identifiable {
    /// The color, fading toward white.
    case tint
    /// The color turning 40° round the wheel as it pales, on the clip's lightness and colorfulness.
    case analogous
    /// One hue, light to pale, on the clip's lightness and colorfulness.
    case monochrome

    var id: String { rawValue }

    var title: String { Self.details[self]?.title ?? rawValue }
    var summary: String { Self.details[self]?.summary ?? "" }

    /// The palette for `color`.
    func palette(for color: RGBA) -> BokehPalette {
        (Self.details[self]?.make ?? BokehPalette.tint)(color)
    }

    /// Each look's name, one line on it, and how it builds its palette, in one table rather than a
    /// switch per property.
    private struct Detail {
        let title: String
        let summary: String
        let make: (RGBA) -> BokehPalette
    }

    private static let details: [BokehColorLook: Detail] = [
        .tint: Detail(title: String(localized: "Tint"), summary: String(localized: "The color, fading toward white."), make: BokehPalette.tint),
        .analogous: Detail(title: String(localized: "Analogous"),
                           summary: String(localized: "The color turning toward its neighbour as it pales, the way Golden hour turns orange to gold."),
                           make: BokehPalette.analogous),
        .monochrome: Detail(title: String(localized: "Monochrome"),
                            summary: String(localized: "One hue, from light to pale, as calm as Golden hour."), make: BokehPalette.monochrome),
    ]
}
