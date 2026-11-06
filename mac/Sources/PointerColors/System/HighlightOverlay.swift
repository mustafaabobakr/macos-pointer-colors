import AppKit
import Observation

/// Shows the ring, pulse and laser in one transparent window per display.
///
/// The windows cover whole displays so a laser trail can go anywhere, ignore the mouse so clicks
/// pass straight through, and show on every Space and over full-screen apps. They exist only while
/// something is switched on, and the mouse is only watched then. Everything in them is a Core
/// Animation layer that the app moves or hands an animation to, so nothing is redrawn per frame.
///
/// A laser drag with its keys held goes through the session event tap when Accessibility allows it:
/// the tap sees the press before any app and drops it, so even a game that reads the mouse on its own
/// can't take the drag. Without the tap, the windows catch the mouse instead.
@MainActor
final class HighlightOverlay {
    private let settings: PointerHighlight
    private let pair: () -> PointerPair
    private let pointerScale: () -> Double
    private let tap: MouseEventTap
    private var style = HighlightStyle()
    private var windows: [NSPanel] = []
    /// Each display's layers, with the display's frame in global coordinates.
    private var displays: [DisplayLayers] = []
    private var monitors: [Any] = []
    private var lostReleaseTimer: Timer?
    /// The windows are catching the mouse so a drag with the laser's keys held draws instead of reaching the app below.
    private var isCapturing = false
    /// The tap took the press that started this laser drag, so it also takes the drag and the release.
    private var tapOwnsDrag = false
    private var isWatchingTap = false

    private static let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                                        .otherMouseDragged, .leftMouseDown, .rightMouseDown,
                                                        .otherMouseDown, .leftMouseUp, .rightMouseUp,
                                                        .otherMouseUp, .flagsChanged]

    init(settings: PointerHighlight, pair: @escaping () -> PointerPair, pointerScale: @escaping () -> Double) {
        self.settings = settings
        self.pair = pair
        self.pointerScale = pointerScale
        tap = .shared
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
            _ = drawsWithKeys
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
        watchTap()
    }

    /// Hooks into the tap while the laser draws with keys. Setting a handler rebuilds the tap, so only on a change.
    private func watchTap() {
        guard drawsWithKeys != isWatchingTap else { return }
        isWatchingTap = drawsWithKeys
        tapOwnsDrag = false
        tap.set(Self.tapID, types: [.leftMouseDown, .leftMouseDragged, .leftMouseUp],
                handler: isWatchingTap ? { [weak self] in self?.tapEvent($0, $1) ?? .pass } : nil)
    }

    /// The laser draws only while its keys are held, the one case where a drag must not reach the app.
    private var drawsWithKeys: Bool { settings.laserOn && settings.laserTrail && settings.laserNeedsKeys }

    private static let tapID = "highlightLaser"

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
        if tapOwnsDrag, Self.leftButtonTypes.contains(type) { return }
        let point = NSEvent.mouseLocation
        let keysHeld = settings.laserKeysHeld(in: NSEvent.modifierFlags)
        updateCapture(keysHeld: keysHeld)
        switch type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            press(at: point, isLeft: type == .leftMouseDown, keysHeld: keysHeld)
        case .leftMouseDragged:
            let draws = settings.laserDraws(keysHeld: keysHeld)
            follow(point, drawing: draws)
            if draws { extendTrail(to: point) }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            release(at: point)
        default:
            follow(point, drawing: false)
        }
    }

    private static let leftButtonTypes: Set<NSEvent.EventType> = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]

    /// A click sends out a pulse, and starts a laser trail with the left button; both when both are on.
    private func press(at point: CGPoint, isLeft: Bool, keysHeld: Bool) {
        pressPulse(at: point, isLeft: isLeft)
        if isLeft, settings.laserDraws(keysHeld: keysHeld) { startTrail(at: point) }
    }

    /// The button came up: the trail fades and, after a long press, a pulse goes out.
    private func release(at point: CGPoint) {
        releasePulse(at: point)
        displays.forEach { $0.laser.finishStroke(style: style) }
    }

    /// The ring, the long-press ring and the laser dot follow the pointer.
    private func follow(_ point: CGPoint, drawing: Bool) {
        placeRing(at: point)
        for display in displays {
            display.pulses.moveHold(to: local(point, in: display.frame))
        }
        moveDot(to: point, drawing: drawing)
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
        let reach = 22 * style.pointerScale * style.ringSize + 2
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
    /// away from at once. When it isn't shown for this move, it is left to fade.
    private func moveDot(to point: CGPoint, drawing: Bool) {
        guard settings.laserDotShows(drawing: drawing) else { return }
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

    /// While the laser needs keys and they're held, the windows take the mouse: the drag draws, and the
    /// app underneath gets no click to select text with. A drag already under way keeps its owner.
    private func updateCapture(keysHeld: Bool) {
        let capture = !tap.isRunning && drawsWithKeys && keysHeld
        guard capture != isCapturing, NSEvent.pressedMouseButtons == 0 else { return }
        isCapturing = capture
        windows.forEach { $0.ignoresMouseEvents = !capture }
    }

    /// A release that never reached us, e.g. over a window that kept it, still ends the press.
    private func endLostPress() {
        if tapOwnsDrag {
            // A dropped press never reaches the session's button state, so ask the hardware.
            guard !CGEventSource.buttonState(.hidSystemState, button: .left) else { return }
            tapOwnsDrag = false
        }
        guard NSEvent.pressedMouseButtons == 0 else { return }
        release(at: NSEvent.mouseLocation)
    }

    // MARK: Event tap

    /// A press with the laser's keys held starts a trail, and it and everything up to its release are
    /// dropped, so the app underneath never sees the drag. Other presses pass untouched.
    private func tapEvent(_ type: CGEventType, _ event: CGEvent) -> MouseEventTap.Verdict {
        let point = NSEvent(cgEvent: event)?.locationInWindow ?? NSEvent.mouseLocation
        switch type {
        case .leftMouseDown: return tapPress(event, at: point)
        case .leftMouseDragged where tapOwnsDrag:
            follow(point, drawing: true)
            extendTrail(to: point)
            return .drop
        case .leftMouseUp where tapOwnsDrag:
            tapOwnsDrag = false
            release(at: point)
            return .drop
        default: return .pass
        }
    }

    private func tapPress(_ event: CGEvent, at point: CGPoint) -> MouseEventTap.Verdict {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        tapOwnsDrag = settings.laserKeysHeld(in: flags) && settings.laserDraws(keysHeld: true)
        guard tapOwnsDrag else { return .pass }
        press(at: point, isLeft: true, keysHeld: true)
        return .drop
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
    /// The pair's dark color, drawn just wider behind each pulse line, as the laser's outline is;
    /// nil with the outline turned off.
    var pulseOutline: RGBA?
    /// How much wider the outline is than the colored line it sits behind: both sides together.
    var pulseOutlineExtra = 2.0
    var laser = LaserColors(glow: RGBA(red: 1, green: 0, blue: 0), outline: RGBA(red: 0, green: 0, blue: 0),
                            middle: RGBA(red: 1, green: 0, blue: 0), center: RGBA(red: 1, green: 1, blue: 1))
    var pointerScale = 1.0
    var pulseSize = 1.0
    var pulseDuration = 0.45
    var showsHold = true
    var pulseStyle = PulseStyle.ring
    var laserSize = 1.0
    var laserLook = LaserLook.classic
    /// Whether the laser has an edge: off when the Outline setting is None.
    var laserOutlined = false
    /// How solid the laser's edge is, from 0.05 to 1.
    var laserOutlineOpacity = 1.0
    var ringSize = 1.0
    var trailFade = 0.9

    init() {}

    @MainActor
    init(settings: PointerHighlight, pair: PointerPair, pointerScale: Double) {
        showsRing = settings.showsRing
        ringColor = pair.highlightColor
        pulseColor = settings.pulseColor(for: pair)
        pulseOutline = settings.pulseOutlined ? pair.darkColor : nil
        pulseOutlineExtra = settings.pulseOutlineWidth * 2
        laser = settings.laserColors(for: pair)
        self.pointerScale = pointerScale
        pulseSize = settings.pulseSize
        pulseDuration = settings.pulseDuration
        showsHold = settings.pulseShowsHold
        pulseStyle = settings.pulseStyle
        laserSize = settings.laserSize
        laserLook = settings.laserLook
        laserOutlined = settings.laserOutline != .none
        laserOutlineOpacity = settings.laserOutlineOpacity
        ringSize = settings.ringSize
        trailFade = settings.laserTrailFade
    }
}

extension HighlightStyle {
    /// The dot's layers, bottom first, each a disc `size` wide, already scaled by `laserSize`.
    var laserDotParts: [LaserPart] {
        switch laserLook {
        case .classic:
            return scaled([LaserPart(laser.glow, 32, opacity: 0.18), LaserPart(laser.outline, 16, opacity: laserOutlineOpacity),
                           LaserPart(laser.middle, 13), LaserPart(laser.center, 11)])
        case .goodNotes:
            // Measured from GoodNotes on a 1:1 display: a solid disc about 7pt wide, barely glowing.
            guard laserOutlined else { return scaled([LaserPart(laser.glow, 7, blur: 1.5)]) }
            // With an edge: the glow alone underneath, so it spreads beyond the edge without
            // tinting it, then the edge, then the disc.
            return scaled([LaserPart(laser.glow, 7, blur: 1.5), LaserPart(laser.outline, 7, opacity: laserOutlineOpacity, rim: Self.goodNotesRim),
                           LaserPart(laser.glow, 7)])
        }
    }

    /// The trail's layers, bottom first, each a line `size` wide, already scaled by `laserSize`.
    var laserTrailParts: [LaserPart] {
        switch laserLook {
        case .classic:
            return scaled([LaserPart(laser.glow, 14, opacity: 0.2), LaserPart(laser.outline, 6, opacity: laserOutlineOpacity),
                           LaserPart(laser.middle, 4), LaserPart(laser.center, 2)])
        case .goodNotes:
            // Measured from GoodNotes: a line up to 14pt wide around a white core about a third of
            // it, glowing about half as bright as the line at its edge and fading out some 9pt
            // beyond. These are the widest; `LaserPace` thins them as the pointer speeds up.
            guard laserOutlined else {
                return scaled([LaserPart(laser.glow, 14, blur: 4), LaserPart(laser.center, 4.4)])
            }
            // With an edge, built like the dot: glow, edge, line, then the core.
            return scaled([LaserPart(laser.glow, 14, blur: 4), LaserPart(laser.outline, 14, opacity: laserOutlineOpacity, rim: Self.goodNotesRim),
                           LaserPart(laser.glow, 14), LaserPart(laser.center, 4.4)])
        }
    }

    /// How much wider the GoodNotes edge is than the line it sits behind, both sides together.
    /// It stays this wide however fast the pointer moves, so a thin flick keeps its edge.
    static let goodNotesRim = 2.4

    /// GoodNotes thins its trail as the pointer speeds up; Classic keeps one width.
    var trailVariesWithSpeed: Bool { laserLook == .goodNotes }

    /// GoodNotes keeps a finished trail whole, then fades it over this long.
    static let goodNotesFade = 0.35

    /// A trail's opacity while it's drawn: GoodNotes draws it solid.
    var trailOpacity: Double { laserLook == .goodNotes ? 1 : 0.95 }

    /// How long a finished trail stays at full opacity, out of `trailFade`, before fading. Classic
    /// fades from the release; GoodNotes holds it and fades over the last `goodNotesFade` seconds.
    var trailHold: Double { laserLook == .goodNotes ? max(trailFade - Self.goodNotesFade, 0) : 0 }

    /// A finished trail's opacity `elapsed` seconds after the release.
    func trailOpacity(after elapsed: Double) -> Double {
        let fading = max(trailFade - trailHold, 0.01)
        return trailOpacity * (1 - min(max((elapsed - trailHold) / fading, 0), 1))
    }

    private func scaled(_ parts: [LaserPart]) -> [LaserPart] {
        parts.map {
            LaserPart($0.color, $0.size * laserSize, opacity: $0.opacity, blur: $0.blur * laserSize,
                      rim: $0.rim * laserSize)
        }
    }
}

/// One layer of the laser: a color, how wide it is, and how far its glow spreads, if it has one.
struct LaserPart: Equatable {
    var color: RGBA
    var size: Double
    var opacity: Double
    /// The radius of a glow in `color` around the layer; 0 for none.
    var blur: Double
    /// Width added to `size` that doesn't thin with speed, as for an edge; 0 for none.
    var rim: Double

    init(_ color: RGBA, _ size: Double, opacity: Double = 1, blur: Double = 0, rim: Double = 0) {
        (self.color, self.size, self.opacity, self.blur, self.rim) = (color, size, opacity, blur, rim)
    }

    /// The full width at its widest, rim included.
    var width: Double { size + rim }
}

/// The laser's soft glow, the outline around its core, and the core's middle and center.
struct LaserColors: Equatable {
    var glow: RGBA
    var outline: RGBA
    var middle: RGBA
    var center: RGBA
}

struct Pulse: Equatable {
    /// Every pulse grows out of a dot this wide (1pt radius) under the pointer, so it reads as
    /// spreading from the click.
    static let startSide = 2.0

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
    /// Size against the pulse's base diameter.
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
    /// Each point's share of the widest line, from how fast the pointer was moving there.
    var shares: [Double] = []
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
    private var pace = LaserPace()
    /// Bumped on every change, so the canvases redraw.
    var revision = 0

    /// Something is fading, so the canvases keep animating.
    var isAnimating: Bool { !pulses.isEmpty || hold != nil || laserDot != nil || !strokes.isEmpty }

    /// The laser dot follows the pointer.
    func move(to point: CGPoint, now: TimeInterval, settings: PointerHighlight) {
        pointer = point
        if hold?.releasedAt == nil { hold?.point = point }
        guard settings.laserDotShows(drawing: false) else { return }
        laserDot = LaserDot(point: point, updatedAt: now)
    }

    /// Dragging moves the dot and, with the trail on, draws.
    func drag(to point: CGPoint, now: TimeInterval, keysHeld: Bool, settings: PointerHighlight) {
        move(to: point, now: now, settings: settings)
        guard settings.laserDraws(keysHeld: keysHeld) else { return }
        if settings.laserDotShows(drawing: true) { laserDot = LaserDot(point: point, updatedAt: now) }
        extendStroke(to: point, now: now)
    }

    /// A click starts a pulse, and a laser trail with the left button; both when both are on.
    func press(at point: CGPoint, now: TimeInterval, isLeft: Bool, keysHeld: Bool, settings: PointerHighlight) {
        pointer = point
        if isLeft, settings.laserDraws(keysHeld: keysHeld) { startStroke(at: point, now: now) }
        guard settings.pulses(isLeft: isLeft) else { return }
        pulses.append(Pulse(point: point, start: now))
        if settings.pulseShowsHold { hold = Hold(point: point, start: now) }
    }

    func startStroke(at point: CGPoint, now: TimeInterval) {
        pace = LaserPace()
        let share = pace.share(at: point, time: now)
        strokes.append(LaserStroke(points: [point, point], shares: [share, share]))
    }

    /// Adds a point to the stroke being drawn, skipping ones too close to the last.
    func extendStroke(to point: CGPoint, now: TimeInterval) {
        guard let index = strokes.lastIndex(where: { $0.finishedAt == nil }) else { return startStroke(at: point, now: now) }
        guard let last = strokes[index].points.last, hypot(last.x - point.x, last.y - point.y) >= 2.5 else { return }
        strokes[index].points.append(point)
        strokes[index].shares.append(pace.share(at: point, time: now))
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
