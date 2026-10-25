import AppKit
import Observation

/// Shows the ring, pulse and laser in one transparent window per display.
///
/// The windows cover whole displays so a laser trail can go anywhere, ignore the mouse so clicks
/// pass straight through, and show on every Space and over full-screen apps. They exist only while
/// something is switched on, and the mouse is only watched then. Everything in them is a Core
/// Animation layer that the app moves or hands an animation to, so nothing is redrawn per frame.
@MainActor
final class HighlightOverlay {
    private let settings: PointerHighlight
    private let pair: () -> PointerPair
    private let pointerScale: () -> Double
    private var style = HighlightStyle()
    private var windows: [NSPanel] = []
    /// Each display's layers, with the display's frame in global coordinates.
    private var displays: [DisplayLayers] = []
    private var monitors: [Any] = []
    private var lostReleaseTimer: Timer?
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

    /// Shows the current pair, size and settings.
    func refresh() {
        style = HighlightStyle(settings: settings, pair: pair(), pointerScale: pointerScale())
        placeRing(at: NSEvent.mouseLocation)
        displays.forEach { $0.laser.restyleStroke(style) }
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
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
            return event
        }
        monitors = [global, local].compactMap { $0 }
        lostReleaseTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.endLostPress() }
        }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        lostReleaseTimer?.invalidate()
        lostReleaseTimer = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
        displays = []
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        displays = []
        windows = settings.isActive ? NSScreen.screens.map(makeWindow) : []
        placeRing(at: NSEvent.mouseLocation)
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
        let layers = DisplayLayers(frame: screen.frame, ring: RingLayerView(frame: bounds),
                                   laser: LaserLayerView(frame: bounds), pulses: PulseLayerView(frame: bounds))
        for view in [layers.ring, layers.laser, layers.pulses] as [NSView] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        displays.append(layers)
        panel.contentView = container
        panel.setFrame(screen.frame, display: false)
        panel.orderFrontRegardless()
        return panel
    }

    // MARK: Events

    private func handle(_ type: NSEvent.EventType) {
        let point = NSEvent.mouseLocation
        let optionHeld = NSEvent.modifierFlags.contains(.option)
        updateCapture(optionHeld: optionHeld)
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            press(at: point, isLeft: type == .leftMouseDown, optionHeld: optionHeld)
        case .leftMouseDragged:
            follow(point)
            if settings.laserDraws(optionHeld: optionHeld) { extendTrail(to: point) }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            release(at: point)
        default:
            follow(point)
        }
    }

    /// A click sends out a pulse, and starts a laser trail with the left button; both when both are on.
    private func press(at point: CGPoint, isLeft: Bool, optionHeld: Bool) {
        pressPulse(at: point, isLeft: isLeft)
        if isLeft, settings.laserDraws(optionHeld: optionHeld) { startTrail(at: point) }
    }

    /// The button came up: the trail fades and, after a long press, a pulse goes out.
    private func release(at point: CGPoint) {
        releasePulse(at: point)
        displays.forEach { $0.laser.finishStroke(fade: style.trailFade) }
    }

    /// The ring, the long-press ring and the laser dot follow the pointer.
    private func follow(_ point: CGPoint) {
        placeRing(at: point)
        for display in displays {
            display.pulses.moveHold(to: local(point, in: display.frame))
        }
        moveDot(to: point)
    }

    /// Within reach of a display: an effect near the edge also shows on the display next to it.
    private func isNear(_ point: CGPoint, _ frame: CGRect, reach: Double) -> Bool {
        frame.insetBy(dx: -reach, dy: -reach).contains(point)
    }

    /// A global point in a display's own coordinates (origin bottom left, like the layers).
    private func local(_ point: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
    }

    // MARK: Ring

    /// The ring shows only on the displays the pointer is on or near.
    private func placeRing(at point: CGPoint) {
        let reach = 22 * style.pointerScale + 2
        for display in displays {
            let spot = isNear(point, display.frame, reach: reach) ? local(point, in: display.frame) : nil
            display.ring.place(at: spot, style: style)
        }
    }

    // MARK: Pulses

    /// A pulse, and a long-press ring if the press lasts, on the displays the point is on or near.
    private func pressPulse(at point: CGPoint, isLeft: Bool) {
        guard settings.pulses(isLeft: isLeft) else { return }
        for display in displays where isNear(point, display.frame, reach: pulseReach) {
            let spot = local(point, in: display.frame)
            display.pulses.pulse(at: spot, style: style)
            if settings.pulseShowsHold { display.pulses.beginHold(at: spot, style: style) }
        }
    }

    /// Ends a long-press ring; after a long press, a pulse goes out from where it was let go.
    private func releasePulse(at point: CGPoint) {
        for display in displays where display.pulses.endHold() {
            display.pulses.pulse(at: local(point, in: display.frame), style: style)
        }
    }

    /// How far a pulse reaches from its point: a ripple at its widest.
    private var pulseReach: Double { 44 * style.pointerScale * style.pulseSize * 1.2 }

    // MARK: Laser

    /// The dot shows only on the displays the pointer is on or near, and leaves the one it moved
    /// away from at once.
    private func moveDot(to point: CGPoint) {
        guard settings.laserOn else { return }
        let reach = 16 * style.laserSize
        for display in displays {
            if isNear(point, display.frame, reach: reach) {
                display.laser.moveDot(to: local(point, in: display.frame), style: style)
            } else {
                display.laser.hideDot()
            }
        }
    }

    /// A trail is drawn on every display, so a drag can cross from one to the next.
    private func startTrail(at point: CGPoint) {
        displays.forEach { $0.laser.startStroke(at: local(point, in: $0.frame), style: style) }
    }

    private func extendTrail(to point: CGPoint) {
        displays.forEach { $0.laser.extendStroke(to: local(point, in: $0.frame), style: style) }
    }

    /// While the laser needs ⌥ and ⌥ is held, the windows take the mouse: the drag draws, and the
    /// app underneath gets no click to select text with. A drag already under way keeps its owner.
    private func updateCapture(optionHeld: Bool) {
        let capture = settings.laserOn && settings.laserNeedsOption && optionHeld
        guard capture != isCapturing, NSEvent.pressedMouseButtons == 0 else { return }
        isCapturing = capture
        windows.forEach { $0.ignoresMouseEvents = !capture }
    }

    /// A release that never reached us, e.g. over a window that kept it, still ends the press.
    private func endLostPress() {
        guard NSEvent.pressedMouseButtons == 0 else { return }
        release(at: NSEvent.mouseLocation)
    }
}

/// One display's layers, and its frame in global coordinates.
private struct DisplayLayers {
    let frame: CGRect
    let ring: RingLayerView
    let laser: LaserLayerView
    let pulses: PulseLayerView
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

/// Everything a HighlightCanvas draws, like the demo pad in Preferences, in its own coordinates.
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
