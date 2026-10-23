import AppKit
import SwiftUI

/// The classic arrow pointer, in a 24×30 design space (same path as the website).
struct PointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            .init(x: 3, y: 2), .init(x: 3, y: 24), .init(x: 8.6, y: 18.8), .init(x: 12.2, y: 27.2),
            .init(x: 16, y: 25.6), .init(x: 12.4, y: 17.4), .init(x: 19.8, y: 17.4),
        ]
        let scale = min(rect.width / 24, rect.height / 30)
        var path = Path()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x * scale, y: rect.minY + $0.y * scale) })
        path.closeSubpath()
        return path
    }
}

/// A pointer drawn in a pair's colors.
struct PointerGlyph: View {
    let pair: PointerPair
    var lineWidth: CGFloat = 1.6

    var body: some View {
        PointerShape()
            .fill(pair.fill.color)
            .overlay(PointerShape().stroke(pair.outline.color, style: .init(lineWidth: lineWidth, lineJoin: .round)))
            .aspectRatio(24.0 / 30.0, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

enum MenuBarIcon {
    /// A small pointer for the menu bar: in the pair's colors, or a template image that follows the menu bar.
    @MainActor
    static func image(for pair: PointerPair, colored: Bool) -> NSImage {
        let glyph = colored
            ? AnyView(PointerGlyph(pair: pair, lineWidth: 1.4))
            : AnyView(PointerShape().fill(Color.black))
        let renderer = ImageRenderer(content: glyph.frame(width: 13, height: 16).padding(1))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil)!
        image.isTemplate = !colored
        image.accessibilityDescription = "Pointer Colors"
        return image
    }
}
