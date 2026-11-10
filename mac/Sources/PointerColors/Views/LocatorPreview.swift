import SwiftUI

/// The pointer locator's ring closing in on a pointer, at real size and in the pair's colors,
/// drawn with the same look as the real one. It plays when it appears and whenever a setting
/// changes, then again after a short rest.
struct LocatorPreview: View {
    let look: LocatorLook
    let pair: PointerPair
    let pointerScale: Double
    @State private var startedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTextScale) private var scale

    /// The rest between plays, in seconds.
    private static let rest = 1.0

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, now: timeline.date)
            }
        }
        .background(Color(white: 0.12))
        .overlay { pointer }
        .frame(maxWidth: .infinity)
        .frame(height: look.side(pointerScale: pointerScale))
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        .accessibilityHidden(true)
        .task(id: look) { await play() }
    }

    /// The pointer with its tip in the middle, where the ring closes, as large as on screen.
    private var pointer: some View {
        let width = 14 * pointerScale
        let unit = width / 24
        return PointerGlyph(pair: pair)
            .frame(width: width)
            .offset(x: width / 2 - 3 * unit, y: width * 30 / 48 - 2 * unit)
    }

    private func play() async {
        while !Task.isCancelled {
            startedAt = .now
            try? await Task.sleep(for: .seconds(look.duration))
            startedAt = nil
            try? await Task.sleep(for: .seconds(Self.rest))
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, now: Date) {
        guard let startedAt else { return }
        let progress = now.timeIntervalSince(startedAt) / look.duration
        guard progress < 1 else { return }
        let radius = look.radius(at: progress, pointerScale: pointerScale, reduceMotion: reduceMotion)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.opacity = LocatorLook.opacity(at: progress)
        context.stroke(circle, with: .color(pair.outline.color), lineWidth: look.outlineWidth)
        context.stroke(circle, with: .color(pair.fill.color), lineWidth: look.fillWidth)
    }
}
