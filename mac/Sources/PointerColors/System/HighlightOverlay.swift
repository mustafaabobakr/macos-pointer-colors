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
    /// Each display's pulse layers, with the display's frame in global coordinates.
    private var pulseViews: [(frame: CGRect, view: PulseLayerView)] = []
    private var monitors: [Any] = []
    private var pruneTimer: Timer?
    /// The windows are catching the mouse so a ⌥-drag draws instead of reaching the app below.
    private var isCapturing = false

    private static let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                                        .otherMouseDragged, .leftMouseDown, .rightMouseDown,
                                                        .otherMouseDown, .leftMouseUp, .rightMouseUp,
                                                        .otherMouseUp, .flagsChanged]

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
        pulseViews = []
        scene.clear()
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        pulseViews = []
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
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        let container = NSView(frame: bounds)
        let drawing = NSHostingView(rootView: HighlightCanvas(scene: scene, screenFrame: screen.frame))
        let pulses = PulseLayerView(frame: bounds)
        for view in [drawing, pulses] as [NSView] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        pulseViews.append((screen.frame, pulses))
        panel.contentView = container
        panel.setFrame(screen.frame, display: false)
        panel.orderFrontRegardless()
        return panel
    }

    // MARK: Events


    private func handle(_ type: NSEvent.EventType) {
        let point = NSEvent.mouseLocation
        let now = Date.timeIntervalSinceReferenceDate
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        updateCapture(optionHeld: optionHeld)
        scene.pointer = point
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            scene.press(at: point, now: now, isLeft: type == .leftMouseDown, optionHeld: optionHeld, settings: settings)
            pressPulse(at: point, isLeft: type == .leftMouseDown)
        case .leftMouseDragged:
            scene.drag(to: point, now: now, optionHeld: optionHeld, settings: settings)
            pulseViews.forEach { $0.view.moveHold(to: local(point, in: $0.frame)) }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            scene.release(at: now)
            releasePulse(at: point)
        default:
            scene.move(to: point, now: now, settings: settings)
            pulseViews.forEach { $0.view.moveHold(to: local(point, in: $0.frame)) }
        }
        // A plain move changes nothing on screen unless the ring or the laser follows it.
        guard scene.style.showsRing || settings.laserOn || type != .mouseMoved else { return }
        scene.revision += 1
    }

    // MARK: Pulses

    /// A pulse, and a long-press ring if the press lasts, on the displays the point is on or near.
    private func pressPulse(at point: CGPoint, isLeft: Bool) {
        guard settings.pulses(isLeft: isLeft) else { return }
        for (frame, view) in pulseViews where isNear(point, frame) {
            view.pulse(at: local(point, in: frame), style: scene.style)
            if settings.pulseShowsHold { view.beginHold(at: local(point, in: frame), style: scene.style) }
        }
    }

    /// Ends a long-press ring; after a long press, a pulse goes out from where it was let go.
    private func releasePulse(at point: CGPoint) {
        for (frame, view) in pulseViews where view.endHold() {
            view.pulse(at: local(point, in: frame), style: scene.style)
        }
    }

    /// Within reach of a display: a pulse near the edge also shows on the display next to it.
    private func isNear(_ point: CGPoint, _ frame: CGRect) -> Bool {
        let reach = 44 * scene.style.pointerScale * scene.style.pulseSize * 1.2
        return frame.insetBy(dx: -reach, dy: -reach).contains(point)
    }

    /// A global point in a display's own coordinates (origin bottom left, like the layers).
    private func local(_ point: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    /// While the laser needs ⌥ and ⌥ is held, the windows take the mouse: the drag draws, and the
    /// app underneath gets no click to select text with. A drag already under way keeps its owner.
    private func updateCapture(optionHeld: Bool) {
        let capture = settings.laserOn && settings.laserNeedsOption && optionHeld
        guard capture != isCapturing, NSEvent.pressedMouseButtons == 0 else { return }
        isCapturing = capture
        windows.forEach { $0.ignoresMouseEvents = !capture }
    }

    /// Drops what has faded, so the drawing stops once nothing is left.
    private func prune() {
        let now = Date.timeIntervalSinceReferenceDate
        // A release that never reached us, e.g. over a window that kept it, still ends the hold.
        if NSEvent.pressedMouseButtons == 0 { scene.release(at: now) }
        if scene.prune(at: now) { scene.revision += 1 }
    }
}

// MARK: - What's on screen

/// Colors and sizes for drawing, worked out once per change instead of on every frame.
struct HighlightStyle: Equatable {
    var showsRing = false
    var ringColor = RGBA(red: 1, green: 1, blue: 1)
    var pulseColor = RGBA(red: 1, green: 1, blue: 1)
    var laser = LaserColors(glow: RGBA(red: 1, green: 0, blue: 0), middle: RGBA(red: 1, green: 0, blue: 0),
                            center: RGBA(red: 1, green: 1, blue: 1))
    var pointerScale = 1.0
    var pulseSize = 1.0
    var pulseDuration = 0.45
    var showsHold = true
    var pulseStyle = PulseStyle.ring
    var laserSize = 1.0
    var trailFade = 0.9

    init() {}

    @MainActor
    init(settings: PointerHighlight, pair: PointerPair, pointerScale: Double) {
        showsRing = settings.showsRing
        ringColor = pair.highlightColor
        pulseColor = settings.pulseColor(for: pair)
        let colors = settings.laserColors(for: pair)
        laser = LaserColors(glow: colors.glow, middle: colors.middle, center: colors.center)
        self.pointerScale = pointerScale
        pulseSize = settings.pulseSize
        pulseDuration = settings.pulseDuration
        showsHold = settings.pulseShowsHold
        pulseStyle = settings.pulseStyle
        laserSize = settings.laserSize
        trailFade = settings.laserTrailFade
    }
}

/// The laser's glow and core, middle and center.
struct LaserColors: Equatable {
    var glow: RGBA
    var middle: RGBA
    var center: RGBA
}

struct Pulse: Equatable {
    let point: CGPoint
    let start: TimeInterval
}

/// A press held longer than a click: a small filled ring under the pointer until release, when it
/// fades and a click pulse goes out from it. A quick click never shows it.
struct Hold: Equatable {
    /// Held this long, a press counts as a long press.
    static let threshold: TimeInterval = 0.35
    /// How long the ring takes to grow in, and to fade after release.
    static let grow: TimeInterval = 0.15
    static let release: TimeInterval = 0.12
    /// Size against a click pulse's starting ring.
    static let size = 0.55

    var point: CGPoint
    let start: TimeInterval
    var releasedAt: TimeInterval?
}

struct LaserDot: Equatable {
    static let fade: TimeInterval = 0.42
    let point: CGPoint
    let updatedAt: TimeInterval
}

struct LaserStroke: Equatable {
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
    var hold: Hold?
    var laserDot: LaserDot?
    var strokes: [LaserStroke] = []
    /// Bumped on every change, so the canvases redraw.
    var revision = 0

    /// Something is fading, so the canvases keep animating.
    var isAnimating: Bool { !pulses.isEmpty || hold != nil || laserDot != nil || !strokes.isEmpty }

    /// The laser dot follows the pointer.
    func move(to point: CGPoint, now: TimeInterval, settings: PointerHighlight) {
        pointer = point
        if hold?.releasedAt == nil { hold?.point = point }
        guard settings.laserOn else { return }
        laserDot = LaserDot(point: point, updatedAt: now)
    }

    /// Dragging moves the dot and, with the trail on, draws.
    func drag(to point: CGPoint, now: TimeInterval, optionHeld: Bool, settings: PointerHighlight) {
        move(to: point, now: now, settings: settings)
        guard settings.laserDraws(optionHeld: optionHeld) else { return }
        extendStroke(to: point)
    }

    /// A click starts a pulse, and a laser trail with the left button; both when both are on.
    func press(at point: CGPoint, now: TimeInterval, isLeft: Bool, optionHeld: Bool, settings: PointerHighlight) {
        pointer = point
        if isLeft, settings.laserDraws(optionHeld: optionHeld) { startStroke(at: point) }
        guard settings.pulses(isLeft: isLeft) else { return }
        pulses.append(Pulse(point: point, start: now))
        if settings.pulseShowsHold { hold = Hold(point: point, start: now) }
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

    /// The button came up: ends the trail and, after a long press, fades the held ring and sends
    /// a pulse out from where it was let go.
    func release(at time: TimeInterval) {
        finishStroke(at: time)
        guard let held = hold, held.releasedAt == nil else { return }
        guard time - held.start >= Hold.threshold else { hold = nil; return }
        hold = Hold(point: held.point, start: held.start, releasedAt: time)
        pulses.append(Pulse(point: held.point, start: time))
    }

    func finishStroke(at time: TimeInterval) {
        guard let index = strokes.lastIndex(where: { $0.finishedAt == nil }) else { return }
        strokes[index].finishedAt = time
    }

    /// Removes faded items. True when something was removed.
    func prune(at now: TimeInterval) -> Bool {
        let before = liveCount
        pulses.removeAll { now - $0.start > style.pulseDuration }
        strokes.removeAll { stroke in stroke.finishedAt.map { now - $0 > style.trailFade } ?? false }
        if let dot = laserDot, now - dot.updatedAt > LaserDot.fade { laserDot = nil }
        if let released = hold?.releasedAt, now - released > Hold.release { hold = nil }
        return liveCount != before
    }

    /// How many things are on screen, to tell when pruning removed one.
    private var liveCount: Int {
        pulses.count + strokes.count + (laserDot == nil ? 0 : 1) + (hold == nil ? 0 : 1)
    }

    func clear() {
        pulses = []
        hold = nil
        strokes = []
        laserDot = nil
    }
}
