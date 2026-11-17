import Foundation

/// The Bokeh pulse's colors, at their brightest and solid, never see-through.
///
/// Measured on every square of the reference clip's 44 clean clicks: each square's color sits on
/// one line from orange (hue 18°, saturation 0.83) to pale gold (hue 38°, saturation 0.45), the
/// more yellow the paler. Brightness is set to the top, as the clip shows on an HDR screen.
enum BokehColors {
    /// The middle square: #FFD07F, its line's brightest point on screen.
    static let middle = RGBA(hex: "FFD07F")!

    /// The hues a flying square can take, in degrees.
    static let hues = 18.0...38.0

    /// The color of a flying square with `hue`: its saturation follows the clip's line from orange
    /// to pale gold, at the top brightness.
    static func square(hue: Double) -> RGBA {
        let share = (hue - hues.lowerBound) / (hues.upperBound - hues.lowerBound)
        return hsv(hue: hue, saturation: 0.83 - 0.38 * share, value: 1)
    }

    private static func hsv(hue: Double, saturation: Double, value: Double) -> RGBA {
        let chroma = value * saturation
        let side = hue / 60
        let second = chroma * (1 - abs(side.truncatingRemainder(dividingBy: 2) - 1))
        let low = value - chroma
        // Hues 0° to 60°, where every Bokeh color lies: red is the strongest, then green.
        return RGBA(red: chroma + low, green: second + low, blue: low)
    }
}
