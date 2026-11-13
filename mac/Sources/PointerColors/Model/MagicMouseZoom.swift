import AppKit
import Observation

/// A double tap on a Magic Mouse zooms in on whatever is under the pointer, in any app and on any
/// display, and the next double tap, or Esc, zooms back out. Over an app in `nativeZoomApps` the
/// double tap is left to macOS's own Smart Zoom instead. Pointer Colors draws the zoom itself,
/// from a screen capture, so it needs Screen Recording.
@MainActor
@Observable
final class MagicMouseZoom {
    var isOn: Bool { didSet { defaults.set(isOn, forKey: Key.isOn); update() } }
    var style: ZoomStyle {
        didSet { defaults.set(style.rawValue, forKey: Key.style); zoom.zoomOut(animated: false); zoom.style = style; keepPointerInside() }
    }
    /// A whole-screen zoom stays where it zoomed in, like macOS Smart Zoom, or follows the pointer.
    var motion: ZoomMotion {
        didSet {
            defaults.set(motion.rawValue, forKey: Key.motion)
            zoom.zoomOut(animated: false)
            zoom.staysPut = motion == .stays
            keepPointerInside()
        }
    }
    /// A still zoom stops the pointer at its display's edges through the event tap, which needs Accessibility.
    var needsAccessibility: Bool { isOn && style == .wholeScreen && motion == .stays }
    /// How many times larger things look.
    var amount: Double { didSet { defaults.set(amount, forKey: Key.amount); zoom.amount = amount } }
    /// The lens's width and height, in points.
    /// The lens's outline: white, the pointer pair's color, or `lensBorderColor`.
    var lensBorder: LensBorder { didSet { defaults.set(lensBorder.rawValue, forKey: Key.lensBorder) } }
    /// The outline's color when `lensBorder` is custom.
    var lensBorderColor: RGBA {
        didSet { defaults.set(try? JSONEncoder().encode(lensBorderColor), forKey: Key.lensBorderColor) }
    }
    /// The color highlights use for the pair on screen, set by the app.
    @ObservationIgnored var pairColor: () -> RGBA = { PointerPair.featured.highlightColor }
    /// A wide lens, a square one or a round one.
    var lensShape: LensShape { didSet { defaults.set(lensShape.rawValue, forKey: Key.lensShape); zoom.lensShape = lensShape } }
    var lensSize: Double {
        didSet { defaults.set(lensSize, forKey: Key.lensSize); zoom.zoomOut(animated: false); zoom.lensSize = lensSize }
    }
    /// Leaves a double tap over an app in `nativeZoomApps` to macOS's own Smart Zoom.
    var leavesNativeZoom: Bool { didSet { defaults.set(leavesNativeZoom, forKey: Key.leavesNativeZoom) } }
    /// Apps with macOS Smart Zoom of their own, for web pages, documents and images.
    var nativeZoomApps: [ZoomApp] {
        didSet { defaults.set(try? JSONEncoder().encode(nativeZoomApps), forKey: Key.nativeZoomApps) }
    }
    /// People you share your screen with in a call see the zoom too.
    var showsInScreenShare: Bool {
        didSet { defaults.set(showsInScreenShare, forKey: Key.showsInScreenShare); zoom.showsInScreenShare = showsInScreenShare }
    }
    /// While the laser's keys are held or it draws, a lens or a following zoom stays where it is, so
    /// the drawing stays over what it marks and its screenshot shows that part zoomed.
    var holdsForLaser: Bool {
        didSet { defaults.set(holdsForLaser, forKey: Key.holdsForLaser); if !holdsForLaser { zoom.isHeld = false } }
    }
    /// Seconds zooming in or out takes; 0 jumps.
    var animationLength: Double {
        didSet { defaults.set(animationLength, forKey: Key.animationLength); zoom.animationLength = animationLength }
    }
    /// Seconds the second tap may come after the first.
    var tapWindow: Double { didSet { defaults.set(tapWindow, forKey: Key.tapWindow); doubleTap.window = tapWindow } }

    nonisolated static let amountRange = 1.5...5.0
    nonisolated static let amountStep = 0.25
    nonisolated static let defaultAmount = 2.0
    nonisolated static let lensSizeRange = 150.0...2000.0
    nonisolated static let lensSizeStep = 10.0
    /// White, a little see-through, as the lens has always been outlined.
    nonisolated static let whiteBorder = RGBA(red: 1, green: 1, blue: 1, alpha: 0.85)
    nonisolated static let defaultLensBorderColor = RGBA(red: 0.04, green: 0.52, blue: 1)
    nonisolated static let defaultLensSize = 300.0
    nonisolated static let animationLengthRange = 0.0...0.6
    nonisolated static let animationLengthStep = 0.05
    nonisolated static let defaultAnimationLength = 0.25
    nonisolated static let tapWindowRange = 0.15...1.0
    /// 10 ms.
    nonisolated static let tapWindowStep = 0.01
    /// The double-click speed set in System Settings › Mouse.
    static var defaultTapWindow: Double {
        min(max(NSEvent.doubleClickInterval, tapWindowRange.lowerBound), tapWindowRange.upperBound)
    }

    /// The Magic Mouse's touches, read while the feature is on.
    let touches = MagicMouseTouches()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let zoom = ScreenZoom()
    @ObservationIgnored private var doubleTap: MagicMouseDoubleTap
    @ObservationIgnored private var clickMonitors: [Any] = []
    @ObservationIgnored private let tap = MouseEventTap.shared

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isOn = defaults.bool(forKey: Key.isOn)
        style = defaults.string(forKey: Key.style).flatMap(ZoomStyle.init) ?? .wholeScreen
        motion = defaults.string(forKey: Key.motion).flatMap(ZoomMotion.init) ?? .stays
        amount = Self.clamped(defaults.object(forKey: Key.amount) as? Double ?? Self.defaultAmount, to: Self.amountRange)
        leavesNativeZoom = defaults.object(forKey: Key.leavesNativeZoom) as? Bool ?? true
        nativeZoomApps = defaults.data(forKey: Key.nativeZoomApps)
            .flatMap { try? JSONDecoder().decode([ZoomApp].self, from: $0) } ?? ZoomApp.defaults
        showsInScreenShare = defaults.object(forKey: Key.showsInScreenShare) as? Bool ?? true
        holdsForLaser = defaults.object(forKey: Key.holdsForLaser) as? Bool ?? true
        lensBorder = defaults.string(forKey: Key.lensBorder).flatMap(LensBorder.init) ?? .white
        lensBorderColor = defaults.data(forKey: Key.lensBorderColor)
            .flatMap { try? JSONDecoder().decode(RGBA.self, from: $0) } ?? Self.defaultLensBorderColor
        lensShape = defaults.string(forKey: Key.lensShape).flatMap(LensShape.init) ?? .rectangle
        lensSize = Self.clamped(defaults.object(forKey: Key.lensSize) as? Double ?? Self.defaultLensSize, to: Self.lensSizeRange)
        animationLength = Self.clamped(defaults.object(forKey: Key.animationLength) as? Double ?? Self.defaultAnimationLength,
                                       to: Self.animationLengthRange)
        let window = Self.clamped(defaults.object(forKey: Key.tapWindow) as? Double ?? Self.defaultTapWindow, to: Self.tapWindowRange)
        tapWindow = window
        doubleTap = MagicMouseDoubleTap(window: window)
        zoom.style = style
        zoom.staysPut = motion == .stays
        zoom.amount = amount
        zoom.lensSize = lensSize
        zoom.lensShape = lensShape
        zoom.lensBorderColor = { [weak self] in self?.borderColor ?? Self.whiteBorder }
        zoom.animationLength = animationLength
        zoom.showsInScreenShare = showsInScreenShare
        touches.onFrame = { [weak self] fingers, time in self?.frame(fingers: fingers, at: time) }
        update()
    }

    /// The lens outline's color for the current choice.
    var borderColor: RGBA {
        switch lensBorder {
        case .white: Self.whiteBorder
        case .pair: pairColor()
        case .custom: lensBorderColor
        }
    }

    /// The laser wants the zoom held (its keys are held, or it's drawing) or lets it go.
    func laserHolds(_ wantsHold: Bool) {
        let held = wantsHold && holdsForLaser
        if zoom.isHeld != held { zoom.isHeld = held }
    }

    /// A laser screenshot is done; it may ask to end a zoom of this style.
    func laserShotTaken(zoomOut: LaserShotZoomOut) {
        if zoomOut.endsZoom(style) { zoom.zoomOut() }
    }

    /// The zoom is held still for a laser drawing.
    var isHeldForLaser: Bool { zoom.isHeld }

    /// Adds the app at `url`, unless it's in the list already.
    func addNativeZoomApp(at url: URL) {
        guard let app = ZoomApp(url: url), !nativeZoomApps.contains(where: { $0.id == app.id }) else { return }
        nativeZoomApps.append(app)
    }

    func removeNativeZoomApp(_ id: ZoomApp.ID) {
        nativeZoomApps.removeAll { $0.id == id }
    }

    /// Whether a double tap over the app with `bundleID` is left to macOS. Once Pointer Colors has
    /// zoomed in, its double tap always zooms back out.
    func leavesToMacOS(_ bundleID: String?, isZoomed: Bool) -> Bool {
        guard leavesNativeZoom, !isZoomed, let bundleID else { return false }
        return nativeZoomApps.contains { $0.bundleID == bundleID }
    }

    private func frame(fingers: Int, at time: TimeInterval) {
        guard doubleTap.frame(fingers: fingers, at: time) else { return }
        guard !leavesToMacOS(Self.appUnderPointer(), isZoomed: zoom.isZoomed) else { return }
        zoom.toggle()
    }

    /// The bundle ID of the app whose window is under the pointer.
    private static func appUnderPointer() -> String? {
        let mouse = NSEvent.mouseLocation
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return WindowServer.owner(at: CGPoint(x: mouse.x, y: top - mouse.y))
            .flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
    }

    private func update() {
        keepPointerInside()
        guard isOn else {
            touches.stop()
            zoom.zoomOut(animated: false)
            clickMonitors.forEach(NSEvent.removeMonitor)
            clickMonitors = []
            return
        }
        touches.start()
        watchClicks()
    }

    /// While a still zoom is up, every pointer movement stops short of the display's edges.
    private func keepPointerInside() {
        tap.set(Key.keepInside, types: Self.pointerEvents, handler: needsAccessibility ? { [weak self] _, event in
            self?.zoom.keepInside(event)
            return .pass
        } : nil)
    }

    private static let pointerEvents: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]

    /// A click's finger touches the mouse too, and so does a scroll's flick, so neither must count as a tap.
    private func watchClicks() {
        guard clickMonitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let time = event.timestamp
            MainActor.assumeIsolated { self?.doubleTap.interrupt(at: time) }
        }) { clickMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.doubleTap.interrupt(at: event.timestamp)
            return event
        }) { clickMonitors.append(local) }
    }

    private static func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private enum Key {
        static let isOn = "magicMouseZoom"
        static let style = "magicMouseZoomStyle"
        static let amount = "magicMouseZoomAmount"
        static let lensSize = "magicMouseZoomLensSize"
        static let tapWindow = "magicMouseZoomTapWindow"
        static let animationLength = "magicMouseZoomAnimation"
        static let showsInScreenShare = "magicMouseZoomInScreenShare"
        static let leavesNativeZoom = "magicMouseZoomLeavesNative"
        static let nativeZoomApps = "magicMouseZoomNativeApps"
        static let motion = "magicMouseZoomMotion"
        static let holdsForLaser = "magicMouseZoomHoldsForLaser"
        static let lensShape = "magicMouseZoomLensShape"
        static let lensBorder = "magicMouseZoomLensBorder"
        static let lensBorderColor = "magicMouseZoomLensBorderColor"
        /// The event tap's name for stopping the pointer at a still zoom's edges.
        static let keepInside = "magicMouseZoomKeepInside"
    }
}
