import Foundation

/// A color as hue (degrees), saturation and brightness (value), for blending colors the way the
/// eye reads them: along the color wheel rather than through grey.
struct HSV: Equatable {
    var hue: Double
    var saturation: Double
    var value: Double

    init(hue: Double, saturation: Double, value: Double) {
        self.hue = Self.wrapped(hue)
        self.saturation = min(max(saturation, 0), 1)
        self.value = min(max(value, 0), 1)
    }

    init(_ color: RGBA) {
        let top = max(color.red, color.green, color.blue)
        let chroma = top - min(color.red, color.green, color.blue)
        self.init(hue: Self.hue(of: color, top: top, chroma: chroma), saturation: top > 0 ? chroma / top : 0, value: top)
    }

    var rgba: RGBA {
        let chroma = value * saturation
        let side = hue / 60
        let second = chroma * (1 - abs(side.truncatingRemainder(dividingBy: 2) - 1))
        let low = value - chroma
        let parts = Self.sextant(Int(side) % 6, chroma: chroma, second: second)
        return RGBA(red: parts.0 + low, green: parts.1 + low, blue: parts.2 + low)
    }

    /// `fraction` of the way to `other`, turning the short way round the color wheel.
    func blended(with other: HSV, by fraction: Double) -> HSV {
        var turn = other.hue - hue
        if turn > 180 { turn -= 360 } else if turn < -180 { turn += 360 }
        return HSV(hue: hue + turn * fraction, saturation: saturation + (other.saturation - saturation) * fraction,
                   value: value + (other.value - value) * fraction)
    }

    private static func wrapped(_ hue: Double) -> Double {
        let turned = hue.truncatingRemainder(dividingBy: 360)
        return turned < 0 ? turned + 360 : turned
    }

    private static func hue(of color: RGBA, top: Double, chroma: Double) -> Double {
        guard chroma > 0 else { return 0 }
        if top == color.red { return 60 * ((color.green - color.blue) / chroma) }
        if top == color.green { return 60 * ((color.blue - color.red) / chroma + 2) }
        return 60 * ((color.red - color.green) / chroma + 4)
    }

    private static func sextant(_ index: Int, chroma: Double, second: Double) -> (Double, Double, Double) {
        let parts: [(Double, Double, Double)] = [(chroma, second, 0), (second, chroma, 0), (0, chroma, second),
                                                 (0, second, chroma), (second, 0, chroma), (chroma, 0, second)]
        return parts[max(0, min(index, 5))]
    }
}
