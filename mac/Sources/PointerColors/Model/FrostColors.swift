/// The Frost pulse's colors: sampled from the reference clip for Ice colors, or worked out from
/// the pulse color.
struct FrostColors: Equatable {
    /// The flash and the ring's line.
    var core: RGBA
    /// The glow around the flash.
    var flash: RGBA
    /// The glow on both sides of the ring.
    var glow: RGBA
    /// The haze filling the middle of the ring.
    var center: RGBA
    /// The shards' lit faces and their shaded ones.
    var shard: RGBA
    var shardShade: RGBA

    /// The flash glow's opacity from its middle out, and how solid the ring's glow is.
    static let flashStops = [1, 0.9, 0.2, 0]
    static let glowOpacity = 1.0

    /// `count` gradient locations: the flash's middle-heavy spacing for four, else evenly spread.
    static func locations(count: Int) -> [Double] {
        count == 4 ? [0, 0.3, 0.7, 1] : (0..<count).map { Double($0) / Double(max(count - 1, 1)) }
    }

    /// White, pale blue and cyan, as measured on the clip's dark background.
    static let ice = FrostColors(core: RGBA(red: 1, green: 1, blue: 1), flash: RGBA(hex: "C4E7F9")!,
                                 glow: RGBA(hex: "A8DDF5")!, center: RGBA(hex: "7FD3EE")!,
                                 shard: RGBA(hex: "F2FAFF")!, shardShade: RGBA(hex: "A9D8F5")!)

    /// Deep colors' ice: a stronger blue than the clip's pale one, which darkened turns grey.
    static let deepIce = RGBA(hex: "3FA9E0")!

    /// For light windows: every part a darker shade of `tint` instead of white or pale, so the
    /// burst stands out on a light background.
    static func deep(_ tint: RGBA) -> FrostColors {
        let black = RGBA(red: 0, green: 0, blue: 0)
        return FrostColors(core: tint.mixed(with: black, by: 0.15), flash: tint.mixed(with: black, by: 0.05),
                           glow: tint.mixed(with: black, by: 0.35), center: tint,
                           shard: tint.mixed(with: black, by: 0.2), shardShade: tint.mixed(with: black, by: 0.5))
    }

    /// The same parts in `tint`: white at the core, lighter shades of the tint around it.
    static func tinted(_ tint: RGBA) -> FrostColors {
        let white = RGBA(red: 1, green: 1, blue: 1)
        return FrostColors(core: white, flash: tint.mixed(with: white, by: 0.6), glow: tint,
                           center: tint.mixed(with: white, by: 0.25), shard: tint.mixed(with: white, by: 0.85),
                           shardShade: tint.mixed(with: white, by: 0.45))
    }
}
