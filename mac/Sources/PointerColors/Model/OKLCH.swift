import Foundation

/// A color as perceived lightness, chroma (colorfulness) and hue, in the OKLCH space: two colors
/// with the same lightness look equally light, whatever their hue, which HSV doesn't give. Bokeh's
/// harmony looks keep the clip's lightness and chroma and change only the hue.
struct OKLCH: Equatable {
    var lightness: Double
    var chroma: Double
    /// Degrees round the wheel.
    var hue: Double

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = max(chroma, 0)
        let turned = hue.truncatingRemainder(dividingBy: 360)
        self.hue = turned < 0 ? turned + 360 : turned
    }

    init(_ color: RGBA) {
        let (l, a, b) = Self.lab(fromLinear: Self.linear(color.red), Self.linear(color.green), Self.linear(color.blue))
        self.init(lightness: l, chroma: hypot(a, b), hue: atan2(b, a) * 180 / .pi)
    }

    /// The color, its chroma lowered just enough to fit the screen's colors.
    var rgba: RGBA {
        var low = 0.0
        var high = chroma
        guard !Self.fits(lightness, high, hue) else { return Self.rgba(lightness, high, hue) }
        for _ in 0..<20 {
            let middle = (low + high) / 2
            if Self.fits(lightness, middle, hue) { low = middle } else { high = middle }
        }
        return Self.rgba(lightness, low, hue)
    }

    /// `fraction` of the way to `other`, turning the short way round the wheel.
    func blended(with other: OKLCH, by fraction: Double) -> OKLCH {
        var turn = other.hue - hue
        if turn > 180 { turn -= 360 } else if turn < -180 { turn += 360 }
        return OKLCH(lightness: lightness + (other.lightness - lightness) * fraction,
                     chroma: chroma + (other.chroma - chroma) * fraction, hue: hue + turn * fraction)
    }

    // MARK: Conversion

    private static func linearRGB(_ l: Double, _ c: Double, _ h: Double) -> (Double, Double, Double) {
        let a = c * cos(h * .pi / 180)
        let b = c * sin(h * .pi / 180)
        let l3 = pow(l + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m3 = pow(l - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s3 = pow(l - 0.0894841775 * a - 1.2914855480 * b, 3)
        return (4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
                -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
                -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3)
    }

    private static func fits(_ l: Double, _ c: Double, _ h: Double) -> Bool {
        let (r, g, b) = linearRGB(l, c, h)
        return [r, g, b].allSatisfy { (-0.0001...1.0001).contains($0) }
    }

    private static func rgba(_ l: Double, _ c: Double, _ h: Double) -> RGBA {
        let (r, g, b) = linearRGB(l, c, h)
        return RGBA(red: gamma(r), green: gamma(g), blue: gamma(b))
    }

    private static func lab(fromLinear r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func gamma(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped <= 0.0031308 ? clamped * 12.92 : 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}
