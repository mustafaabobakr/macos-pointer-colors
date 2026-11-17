/// Every color one Bokeh burst draws: the middle square, and the flying squares' colors, blended
/// along a row of color stops round the color wheel, or along harmony ramps in OKLCH that keep
/// the clip's lightness and colorfulness.
struct BokehPalette: Equatable {
    /// The flying squares' colors, from the deep end to the pale end.
    let stops: [HSV]
    /// The harmony looks' colors instead: ramps in OKLCH, each taking its share of the squares.
    let ramps: [BokehRamp]
    /// The middle square.
    let middle: RGBA

    init(stops: [HSV], middle: RGBA) {
        self.stops = stops.isEmpty ? [HSV(hue: 0, saturation: 0, value: 1)] : stops
        self.ramps = []
        self.middle = middle
    }

    init(deep: HSV, pale: HSV, middle: RGBA) {
        self.init(stops: [deep, pale], middle: middle)
    }

    init(ramps: [BokehRamp], middle: RGBA) {
        let first = ramps.first ?? BokehRamp(share: 1, from: OKLCH(lightness: 0.7, chroma: 0, hue: 0), to: OKLCH(lightness: 0.9, chroma: 0, hue: 0))
        self.stops = [HSV(first.from.rgba), HSV(first.to.rgba)]
        self.ramps = ramps
        self.middle = middle
    }

    /// The deepest and palest stops.
    var deep: HSV { stops[0] }
    var pale: HSV { stops[stops.count - 1] }

    /// The clip's: deep orange (18°, saturation 0.83) to pale gold (38°, 0.45), as measured on it.
    static let clip = BokehPalette(deep: HSV(hue: 18, saturation: 0.83, value: 1),
                                   pale: HSV(hue: 38, saturation: 0.45, value: 1), middle: BokehColors.middle)

    /// A flying square's color, from the deep end (0) to the pale end (1).
    func square(shade: Double) -> RGBA {
        guard ramps.isEmpty else { return BokehRamp.color(in: ramps, at: shade) }
        let spot = min(max(shade, 0), 1) * Double(stops.count - 1)
        let index = min(Int(spot), stops.count - 1)
        return stops[index].blended(with: stops[min(index + 1, stops.count - 1)], by: spot - Double(index)).rgba
    }

    /// `color` at its brightest, fading toward white: the look before the others.
    static func tint(_ color: RGBA) -> BokehPalette {
        let top = max(color.red, color.green, color.blue, 0.001)
        let bright = RGBA(red: color.red / top, green: color.green / top, blue: color.blue / top)
        let white = RGBA(red: 1, green: 1, blue: 1)
        return BokehPalette(deep: HSV(bright), pale: HSV(bright.mixed(with: white, by: 0.55)),
                            middle: bright.mixed(with: white, by: 0.5))
    }

    // MARK: Harmony

    /// The clip's lightness and chroma, deep end and pale end, measured in OKLCH on its colors.
    static let clipDeep = OKLCH(lightness: 0.704, chroma: 0.195, hue: 0)
    static let clipPale = OKLCH(lightness: 0.893, chroma: 0.102, hue: 0)

    /// Squares on the clip's ramp: most in `color`'s hue turning `turn` degrees as they pale, the
    /// rest shared between `accents`, hues that many degrees round from it, a little softer.
    static func harmony(_ color: RGBA, turn: Double, accents: [Double] = [], accentShare: Double = 0.2,
                        accentChroma: Double = 0.85) -> BokehPalette {
        // Accents are kept for harmonies with a second hue; Analogous and Monochrome have none.
        let hue = OKLCH(color).hue
        let main = BokehRamp(share: 1 - accentShare * Double(accents.count), hue: hue, turn: turn, chromaScale: 1)
        let others = accents.map { BokehRamp(share: accentShare, hue: hue + $0, turn: 20, chromaScale: accentChroma) }
        return BokehPalette(ramps: [main] + others, middle: OKLCH(lightness: 0.882, chroma: 0.113, hue: hue + turn).rgba)
    }

    /// The color turning 40° round the wheel as it pales, as the clip turns orange to gold.
    static func analogous(_ color: RGBA) -> BokehPalette { harmony(color, turn: 40) }

    /// One hue, from light to pale, on the clip's ramp.
    static func monochrome(_ color: RGBA) -> BokehPalette { harmony(color, turn: 0) }
}

/// One run of Bokeh colors in OKLCH, along the clip's ramp from deep to pale, taking `share` of
/// the squares.
struct BokehRamp: Equatable {
    let share: Double
    let from: OKLCH
    let to: OKLCH

    init(share: Double, from: OKLCH, to: OKLCH) {
        self.share = share
        self.from = from
        self.to = to
    }

    /// The clip's ramp in `hue`, turning `turn` degrees from the deep end to the pale one.
    init(share: Double, hue: Double, turn: Double, chromaScale: Double) {
        let deep = BokehPalette.clipDeep
        let pale = BokehPalette.clipPale
        self.init(share: share, from: OKLCH(lightness: deep.lightness, chroma: deep.chroma * chromaScale, hue: hue),
                  to: OKLCH(lightness: pale.lightness, chroma: pale.chroma * chromaScale, hue: hue + turn))
    }

    /// The color at `shade` across `ramps`: the ramps take their shares of 0 to 1 in turn.
    static func color(in ramps: [BokehRamp], at shade: Double) -> RGBA {
        let total = ramps.reduce(0) { $0 + $1.share }
        var start = 0.0
        for ramp in ramps {
            let end = start + ramp.share / max(total, 0.0001)
            if shade <= end || ramp == ramps.last {
                let within = (shade - start) / max(end - start, 0.0001)
                return ramp.from.blended(with: ramp.to, by: min(max(within, 0), 1)).rgba
            }
            start = end
        }
        return BokehPalette.clip.middle
    }
}
