/// The Bokeh pulse's colors: gold and amber from the reference clip, or shades of the pulse color.
struct BokehColors: Equatable {
    /// The glow frame, the middle square and most of the flying ones.
    var light: RGBA
    /// The warm squares.
    var warm: RGBA

    /// How solid the lines and the filled squares are at their brightest. The clip's pieces are
    /// see-through; these, with the colors below, match what it shows on a dark background.
    static let lineOpacity = 0.5
    static let fillOpacity = 0.45
    /// The glow frame is brighter, since its blur spreads it thin.
    static let frameOpacity = 0.9

    /// Pale gold and amber. At the opacities above over the clip's background (#1A1C24) the pale
    /// gold comes out #817A62, against #838068 measured on the clip's sharpest square; the amber
    /// comes out a little brighter than the #6D5337 measured on a warm square's line.
    static let gold = BokehColors(light: RGBA(hex: "E8D8A0")!, warm: RGBA(hex: "E8A05A")!)

    /// The same parts in `tint`: a pale shade of it, and the tint itself for the warm squares.
    static func tinted(_ tint: RGBA) -> BokehColors {
        BokehColors(light: tint.mixed(with: RGBA(red: 1, green: 1, blue: 1), by: 0.55), warm: tint)
    }
}
