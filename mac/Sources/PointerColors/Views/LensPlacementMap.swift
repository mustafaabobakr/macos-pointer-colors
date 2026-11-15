import SwiftUI

/// A small map of a 1440 × 900 pt display for the lens's settings: a desktop, and the lens itself,
/// magnifying, for the pointer at `pointer`. With `outlinesArea`, the part of the display the lens
/// shows is outlined.
struct LensPlacementMap {
    static let screen = CGSize(width: 1440, height: 900)
    /// Where the pointer starts without an outline: a top-right corner, where placements differ most.
    static let cornerPointer = CGPoint(x: 1400, y: 40)
    /// Where it starts with one: in open space, where the outline is clear.
    static let openPointer = CGPoint(x: 860, y: 600)

    let placement: LensPlacement
    let lens: CGSize
    let shape: LensShape
    let amount: Double
    let view: LensView
    let spot: Double
    let outlinesArea: Bool
    var startPointer: CGPoint { outlinesArea ? Self.openPointer : Self.cornerPointer }

    func draw(in context: GraphicsContext, size: CGSize, pointer: CGPoint, dark: Bool) {
        let scale = size.width / Self.screen.width
        var screen = context
        screen.scaleBy(x: scale, y: scale)
        drawDesktop(in: screen, dark: dark)
        let lensFrame = placement.frame(pointer: pointer, lens: lens, screen: Self.screen)
        let area = view.shownArea(pointer: pointer, lens: lensFrame, amount: amount, spot: spot)
        if outlinesArea { screen.fill(Path(area), with: .color(.yellow.opacity(0.28))) }
        drawLens(lensFrame, showing: area, pointer: pointer, in: context, scale: scale, dark: dark)
        // Over the lens too, so Under the lens shows its outline where it is.
        if outlinesArea { drawArea(area, in: screen, scale: scale) }
        // About 14 points tall on the map, so it reads at any card width.
        Self.drawPointer(in: screen, at: pointer, size: 0.7 / max(scale, 0.01))
    }

    // MARK: Desktop

    private func drawDesktop(in context: GraphicsContext, dark: Bool) {
        let full = CGRect(origin: .zero, size: Self.screen)
        let colors: [Color] = dark ? [Color(red: 0.11, green: 0.16, blue: 0.27), Color(red: 0.23, green: 0.14, blue: 0.28)]
            : [Color(red: 0.61, green: 0.77, blue: 0.94), Color(red: 0.91, green: 0.72, blue: 0.84)]
        context.fill(Path(full), with: .linearGradient(Gradient(colors: colors), startPoint: .zero,
                                                       endPoint: CGPoint(x: full.maxX, y: full.maxY)))
        context.fill(Path(CGRect(x: 0, y: 0, width: full.width, height: 24)), with: .color(.white.opacity(dark ? 0.12 : 0.6)))
        for window in Self.windows { drawWindow(window, in: context, dark: dark) }
        let dock = CGRect(x: full.midX - 300, y: full.height - 66, width: 600, height: 58)
        context.fill(Path(roundedRect: dock, cornerRadius: 16), with: .color(.white.opacity(dark ? 0.15 : 0.5)))
        for (index, color) in Self.dockColors.enumerated() {
            let icon = CGRect(x: dock.minX + 20 + CGFloat(index) * 70, y: dock.minY + 7, width: 44, height: 44)
            context.fill(Path(roundedRect: icon, cornerRadius: 10), with: .color(color))
        }
    }

    private static let windows = [CGRect(x: 18, y: 40, width: 470, height: 280), CGRect(x: 560, y: 120, width: 560, height: 380),
                                  CGRect(x: 980, y: 40, width: 440, height: 230), CGRect(x: 60, y: 520, width: 520, height: 300),
                                  CGRect(x: 1080, y: 560, width: 340, height: 240)]
    private static let dockColors: [Color] = [.blue, .green, .orange, .pink, .purple, .cyan, .yellow, .gray]

    /// A window with a title bar and grey lines of text.
    private func drawWindow(_ frame: CGRect, in context: GraphicsContext, dark: Bool) {
        context.fill(Path(frame.offsetBy(dx: 4, dy: 8)), with: .color(.black.opacity(0.18)))
        context.fill(Path(frame), with: .color(dark ? Color(white: 0.15) : Color(white: 0.985)))
        context.fill(Path(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 28)),
                     with: .color(dark ? Color(white: 0.2) : Color(white: 0.93)))
        for (index, color) in [Color.red, .yellow, .green].enumerated() {
            let light = CGRect(x: frame.minX + 9 + CGFloat(index) * 18, y: frame.minY + 8.5, width: 11, height: 11)
            context.fill(Path(ellipseIn: light), with: .color(color))
        }
        var y = frame.minY + 44
        var line = 0
        while y + 8 < frame.maxY - 10 {
            let width = (frame.width - 32) * [0.92, 0.78, 0.86, 0.6, 0.83][line % 5]
            context.fill(Path(roundedRect: CGRect(x: frame.minX + 16, y: y, width: width, height: 7), cornerRadius: 3),
                         with: .color(dark ? Color(white: 0.75) : Color(white: 0.3)))
            y += 19
            line += 1
        }
    }

    // MARK: Lens

    /// The outline of the part of the display the lens shows.
    private func drawArea(_ area: CGRect, in context: GraphicsContext, scale: CGFloat) {
        let line = 1 / max(scale, 0.01)
        context.stroke(Path(area), with: .color(.yellow), style: StrokeStyle(lineWidth: line * 2.5, dash: [line * 6, line * 4]))
    }

    /// The lens at `frame`, showing `area` of the desktop magnified.
    private func drawLens(_ frame: CGRect, showing area: CGRect, pointer: CGPoint, in context: GraphicsContext,
                          scale: CGFloat, dark: Bool) {
        let shown = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
        let outline = shape == .circle ? Path(ellipseIn: shown) : Path(shown)
        var inside = context
        inside.clip(to: outline)
        inside.translateBy(x: shown.minX, y: shown.minY)
        inside.scaleBy(x: shown.width / area.width, y: shown.height / area.height)
        inside.translateBy(x: -area.minX, y: -area.minY)
        drawDesktop(in: inside, dark: dark)
        Self.drawPointer(in: inside, at: pointer, size: 1)
        context.stroke(outline, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
    }

    // MARK: Pointer

    /// An arrow pointer with its tip at `tip`, `size` times its 20 pt height.
    private static func drawPointer(in context: GraphicsContext, at tip: CGPoint, size: CGFloat) {
        let points: [CGPoint] = [.zero, CGPoint(x: 0, y: 17), CGPoint(x: 4.2, y: 13), CGPoint(x: 7, y: 19.5),
                                 CGPoint(x: 9.6, y: 18.4), CGPoint(x: 6.9, y: 12.2), CGPoint(x: 12.4, y: 12.2)]
        var path = Path()
        path.addLines(points.map { CGPoint(x: tip.x + $0.x * size, y: tip.y + $0.y * size) })
        path.closeSubpath()
        context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 1.4 * size, lineJoin: .round))
        context.fill(path, with: .color(.black))
    }
}
