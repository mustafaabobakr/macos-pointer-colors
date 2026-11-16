/// Where the Bokeh pulse takes its color from.
enum BokehColorSource: String, CaseIterable, Identifiable {
    /// Pale gold and amber, as sampled from the reference clip.
    case gold
    /// The brighter of the pair's colors, following the pair on each display.
    case pair
    /// The color picked in Preferences.
    case custom

    var id: String { rawValue }
}
