import AppKit

/// A zoom for each display, so each one zooms in and out by itself. A double tap, Esc or a laser
/// screenshot acts on the display under the pointer; the others keep their zoom until you go back
/// to them.
@MainActor
final class DisplayZooms {
    /// Makes a new display's zoom with the current settings.
    var make: () -> ScreenZoom = { ScreenZoom() }
    private var zooms: [CGDirectDisplayID: ScreenZoom] = [:]

    /// The zoom of the display under the pointer, made the first time it's needed.
    var underPointer: ScreenZoom? {
        let mouse = NSEvent.mouseLocation
        guard let id = NSScreen.screens.first(where: { $0.frame.contains(mouse) })?.displayID else { return nil }
        if let zoom = zooms[id] { return zoom }
        let zoom = make()
        zooms[id] = zoom
        return zoom
    }

    /// Applies a setting to every display's zoom made so far; later ones get it from `make`.
    func forEach(_ body: (ScreenZoom) -> Void) {
        zooms.values.forEach(body)
    }

    func zoomOutAll(animated: Bool = true) {
        forEach { $0.zoomOut(animated: animated) }
    }
}
