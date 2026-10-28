import SwiftUI

/// A pad in Preferences › Highlight for trying the current settings: move, click and drag in it.
struct HighlightDemoPad: View {
    let highlight: PointerHighlight
    let style: HighlightStyle
    @State private var scene = HighlightScene()
    @State private var isDragging = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12))
            Text(hint).appFont(.caption).foregroundStyle(.white.opacity(0.55))
            HighlightCanvas(scene: scene)
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onContinuousHover(coordinateSpace: .local, perform: hovered)
        .clipHover(perform: hovered)
        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local).onChanged(dragged).onEnded(ended))
        .onAppear { scene.style = style }
        .onChange(of: highlight.pulseOn) { scene.clear() }
        .onChange(of: highlight.laserOn) { scene.clear() }
        .task { await pruneWhileShown() }
        .accessibilityLabel("Highlight demo")
    }

    private var hint: String {
        !highlight.isActive
            ? String(localized: "Turn on Pulse or Laser above, then try it here.")
            : String(localized: "Move, click and drag here to try it.")
    }

    private var now: TimeInterval { Date.timeIntervalSinceReferenceDate }

    private var keysHeld: Bool { highlight.laserKeysHeld(in: NSEvent.modifierFlags) }

    private func hovered(_ phase: HoverPhase) {
        guard case .active(let point) = phase else { return }
        scene.style = style
        scene.move(to: point, now: now, settings: highlight)
        scene.revision += 1
    }

    private func dragged(_ value: DragGesture.Value) {
        scene.style = style
        if isDragging {
            scene.drag(to: value.location, now: now, keysHeld: keysHeld, settings: highlight)
        } else {
            isDragging = true
            scene.press(at: value.location, now: now, isLeft: true, keysHeld: keysHeld, settings: highlight)
        }
        scene.revision += 1
    }

    private func ended(_ value: DragGesture.Value) {
        isDragging = false
        scene.release(at: now)
        scene.revision += 1
    }

    /// Drops what has faded, so the pad stops animating once it's quiet.
    private func pruneWhileShown() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(250))
            if scene.prune(at: now) { scene.revision += 1 }
        }
    }
}
