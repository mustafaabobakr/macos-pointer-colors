/// Where the Frost pulse takes its color from. The flash stays white; the glow, haze and shards
/// are shades of the color.
enum FrostColorSource: String, CaseIterable, Identifiable {
    /// White and icy blue, as sampled from the reference clip.
    case ice
    /// The brighter of the pair's colors, following the pair on each display.
    case pair
    /// The color picked in Preferences.
    case custom

    var id: String { rawValue }
}
