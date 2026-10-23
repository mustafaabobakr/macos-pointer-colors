import AppKit
import SwiftUI

/// An sRGB color with components in 0...1, the shape macOS stores pointer colors in.
struct RGBA: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double = 1

    /// Parses `#RRGGBB` or `RRGGBB`. Returns nil for anything else.
    init?(hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .black
        self.init(red: Double(ns.redComponent), green: Double(ns.greenComponent),
                  blue: Double(ns.blueComponent), alpha: Double(ns.alphaComponent))
    }

    /// Uppercase hex without `#`, ready for the System Settings Hex field.
    var hex: String {
        let channels = [red, green, blue].map { Int(($0 * 255).rounded()).clamped(to: 0...255) }
        return channels.map { String(format: "%02X", $0) }.joined()
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }

    /// The dictionary `com.apple.universalaccess` uses for `cursorOutline` / `cursorFill`.
    var preferenceValue: [String: Double] {
        ["red": red, "green": green, "blue": blue, "alpha": alpha]
    }

    init?(preferenceValue: Any?) {
        guard let dict = preferenceValue as? [String: Any],
              let r = (dict["red"] as? NSNumber)?.doubleValue,
              let g = (dict["green"] as? NSNumber)?.doubleValue,
              let b = (dict["blue"] as? NSNumber)?.doubleValue else { return nil }
        self.init(red: r, green: g, blue: b, alpha: (dict["alpha"] as? NSNumber)?.doubleValue ?? 1)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
