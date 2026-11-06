import AppKit
import SwiftUI

/// The two colors of the battery charts, in use and idle: a blue and an amber that stay apart for
/// color-blind readers, each a step of its own in dark mode.
enum UsageColors {
    static let inUse = dynamic(light: (0.184, 0.435, 0.859), dark: (0.310, 0.525, 0.902))
    static let idle = dynamic(light: (0.753, 0.478, 0.173), dark: (0.769, 0.525, 0.220))

    private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

/// The key to the two colors, drawn outside a chart so it stays put while the chart scrolls.
struct UsageLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            swatch(UsageColors.inUse, "In use")
            swatch(UsageColors.idle, "Idle")
        }
        .appFont(.caption)
        .foregroundStyle(.secondary)
    }

    private func swatch(_ color: Color, _ title: LocalizedStringKey) -> some View {
        Label { Text(title) } icon: { RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 9, height: 9) }
    }
}
