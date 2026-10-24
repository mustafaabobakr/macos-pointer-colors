import AppKit
import Observation
import SwiftUI

/// Draws the ring, pulse and laser in one transparent window per display.
///
/// The windows cover whole displays so a laser trail can go anywhere, ignore the mouse so clicks
/// pass straight through, and show on every Space and over full-screen apps. They exist only while
/// something is switched on, and the mouse is only watched then.
@MainActor
final class HighlightOverlay {
    private let settings: PointerHighlight
    private let pair: () -> PointerPair
    private let pointerScale: () -> Double
    private let scene = HighlightScene()
    private var windows: [NSPanel] = []
    private var monitors: [Any] = []
    private var pruneTimer: Timer?

    private static let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                                        .otherMouseDragged, .leftMouseDown, .rightMouseDown,
                                                        .otherMouseDown, .leftMouseUp]

    init(settings: PointerHighlight, pair: @escaping () -> PointerPair, pointerScale: @escaping () -> Double) {
        self.settings = settings
        self.pair = pair
        self.pointerScale = pointerScale
        observeSettings()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildWindows() }
        }
        DispatchQueue.main.async { [weak self] in self?.update() }
    }

    /// Redraws in the current pair, size and settings.
    func refresh() {
        scene.style = HighlightStyle(settings: settings, pair: pair(), pointerScale: pointerScale())
        scene.revision += 1
    }

    // MARK: On and off

    /// Re-runs `update` whenever a setting changes.
    private func observeSettings() {
        withObservationTracking {
            _ = HighlightStyle(settings: settings, pair: .featured, pointerScale: 1)
            _ = settings.isActive
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.update()
                self?.observeSettings()
            }
        }
    }

    private func update() {
        refresh()
        if settings.isActive { start() } else { stop() }
    }

    private func start() {
        if windows.isEmpty { rebuildWindows() }
        scene.pointer = NSEvent.mouseLocation
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
            return event
        }
        monitors = [global, local].compactMap { $0 }
        pruneTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.prune() }
        }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        pruneTimer?.invalidate()
        pruneTimer = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
        scene.clear()
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = settings.isActive ? NSScreen.screens.map(makeWindow) : []
    }

    private func makeWindow(for screen: NSScreen) -> NSPanel {
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HighlightCanvas(scene: scene, screenFrame: screen.frame))
        panel.setFrame(screen.frame, display: false)
        panel.orderFrontRegardless()
        return panel
    }

    // MARK: Events

    private func handle(_ type: NSEvent.EventType) {
        let point = NSEvent.mouseLocation
        let now = Date.timeIntervalSinceReferenceDate
        scene.pointer = point
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            scene.press(at: point, now: now, isLeft: type == .leftMouseDown, settings: settings)
        case .leftMouseDragged: scene.drag(to: point, now: now, settings: settings)
        case .leftMouseUp: scene.finishStroke(at: now)
        default: scene.move(to: point, now: now, settings: settings)
        }
        // A plain move changes nothing on screen unless the ring or the laser follows it.
        guard scene.style.showsRing || settings.mode == .laser || type != .mouseMoved else { return }
        scene.revision += 1
    }

    /// Drops what has faded, so the drawing stops once nothing is left.
    private func prune() {
        if scene.prune(at: Date.timeIntervalSinceReferenceDate) { scene.revision += 1 }
    }
}

// MARK: - What's on screen

/// Colors and sizes for drawing, worked out once per change instead of on every frame.
struct HighlightStyle {
    var showsRing = false
    var ringColor = RGBA(red: 1, green: 1, blue: 1)
    var pulseColor = RGBA(red: 1, green: 1, blue: 1)
    var laser = (glow: RGBA(red: 1, green: 0, blue: 0), middle: RGBA(red: 1, green: 0, blue: 0),
                 center: RGBA(red: 1, green: 1, blue: 1))
    var pointerScale = 1.0
    var pulseSize = 1.0
    var pulseDuration = 0.45
    var laserSize = 1.0
    var trailFade = 0.9

    init() {}

    @MainActor
    init(settings: PointerHighlight, pair: PointerPair, pointerScale: Double) {
        showsRing = settings.showsRing
        ringColor = pair.outline
        pulseColor = settings.pulseColor(for: pair)
        laser = settings.laserColors(for: pair)
        self.pointerScale = pointerScale
        pulseSize = settings.pulseSize
        pulseDuration = settings.pulseDuration
        laserSize = settings.laserSize
        trailFade = settings.laserTrailFade
    }
}

struct Pulse {
    let point: CGPoint
    let start: TimeInterval
}

struct LaserDot {
    static let fade: TimeInterval = 0.42
    let point: CGPoint
    let updatedAt: TimeInterval
}

struct LaserStroke {
    var points: [CGPoint]
    var finishedAt: TimeInterval?
}

/// Everything the canvases draw, in global screen coordinates.
@MainActor
@Observable
final class HighlightScene {
    var style = HighlightStyle()
    var pointer = CGPoint.zero
    var pulses: [Pulse] = []
    var laserDot: LaserDot?
    var strokes: [LaserStroke] = []
    /// Bumped on every change, so the canvases redraw.
    var revision = 0

    /// Something is fading, so the canvases keep animating.
    var isAnimating: Bool { !pulses.isEmpty || laserDot != nil || !strokes.isEmpty }

    /// The laser dot follows the pointer.
    func move(to point: CGPoint, now: TimeInterval, settings: PointerHighlight) {
        pointer = point
        guard settings.mode == .laser else { return }
        laserDot = LaserDot(point: point, updatedAt: now)
    }

    /// Dragging moves the dot and, with the trail on, draws.
    func drag(to point: CGPoint, now: TimeInterval, settings: PointerHighlight) {
        move(to: point, now: now, settings: settings)
        guard settings.mode == .laser, settings.laserTrail else { return }
        extendStroke(to: point)
    }

    /// A click starts a pulse, or a laser trail with the left button.
    func press(at point: CGPoint, now: TimeInterval, isLeft: Bool, settings: PointerHighlight) {
        pointer = point
        if settings.mode == .laser, settings.laserTrail, isLeft { startStroke(at: point) }
        guard settings.mode == .pulse, isLeft || settings.pulsesOnRightClick else { return }
        pulses.append(Pulse(point: point, start: now))
    }

    func startStroke(at point: CGPoint) {
        strokes.append(LaserStroke(points: [point, point]))
    }

    /// Adds a point to the stroke being drawn, skipping ones too close to the last.
    func extendStroke(to point: CGPoint) {
        guard let index = strokes.lastIndex(where: { $0.finishedAt == nil }) else { return startStroke(at: point) }
        guard let last = strokes[index].points.last, hypot(last.x - point.x, last.y - point.y) >= 2.5 else { return }
        strokes[index].points.append(point)
    }

    func finishStroke(at time: TimeInterval) {
        guard let index = strokes.lastIndex(where: { $0.finishedAt == nil }) else { return }
        strokes[index].finishedAt = time
    }

    /// Removes faded items. True when something was removed.
    func prune(at now: TimeInterval) -> Bool {
        let before = pulses.count + strokes.count + (laserDot == nil ? 0 : 1)
        pulses.removeAll { now - $0.start > style.pulseDuration }
        strokes.removeAll { stroke in stroke.finishedAt.map { now - $0 > style.trailFade } ?? false }
        if let dot = laserDot, now - dot.updatedAt > LaserDot.fade { laserDot = nil }
        return pulses.count + strokes.count + (laserDot == nil ? 0 : 1) != before
    }

    func clear() {
        pulses = []
        strokes = []
        laserDot = nil
    }
}
