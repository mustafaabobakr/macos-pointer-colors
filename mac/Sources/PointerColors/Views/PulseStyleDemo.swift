import SwiftUI

/// One pulse under a still pointer, drawn at real size by the overlay's own drawing code. Still
/// at a telling moment, it plays over and over while the pointer is over it.
struct PulseStyleDemo: View {
    let style: HighlightStyle
    let pair: PointerPair
    @State private var playingSince: Date?
    @Environment(\.previewBackdrop) private var backdrop

    /// The pause between one pulse ending and the next starting while it plays.
    private static let gap = 0.45

    var body: some View {
        TimelineView(.animation(paused: playingSince == nil)) { timeline in
            GeometryReader { proxy in
                let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                let scene = scene(at: center, age: age(at: timeline.date))
                ZStack(alignment: .topLeading) {
                    backdrop.color
                    Canvas { context, _ in
                        HighlightSnapshot(scene: scene, toLocal: { $0 }).draw(in: &context, now: Self.now)
                    }
                    PointerGlyph(pair: pair)
                        .frame(width: 14 * style.pointerScale)
                        .offset(x: center.x - 1, y: center.y - 1)
                }
            }
        }
        .onHover { playingSince = $0 ? .now : nil }
        .accessibilityHidden(true)
    }

    /// A fixed moment the scene is drawn at; the pulse started `age` seconds before it.
    private static let now: TimeInterval = 1_000

    /// Seconds into the pulse: looping while played, else the moment that shows the style best.
    private func age(at date: Date) -> Double {
        guard let playingSince else { return style.pulseDuration * stillShare }
        return date.timeIntervalSince(playingSince).truncatingRemainder(dividingBy: style.pulseDuration + Self.gap)
    }

    private var stillShare: Double {
        switch style.pulseStyle {
        case .ring: 0.35
        case .ripple: 0.45
        case .frost: 0.22
        case .bokeh: 0.3
        }
    }

    private func scene(at center: CGPoint, age: Double) -> HighlightScene {
        let scene = HighlightScene()
        scene.style = style
        scene.pointer = center
        scene.pulses = [Pulse(point: center, start: Self.now - age, seed: 7)]
        return scene
    }
}
