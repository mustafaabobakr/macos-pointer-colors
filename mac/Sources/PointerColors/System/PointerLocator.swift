import AppKit
import Observation
import QuartzCore

/// Press a modifier key twice to see where the pointer is: a ring in the pair's colors closes in
/// on it. The key is ⌃ Control unless changed.
@MainActor
@Observable
final class PointerLocator {
    /// The keys a double press can use, one at a time.
    static let keys: [HoldKeys] = [.control, .option, .shift, .command]

    var isOn: Bool { didSet { defaults.set(isOn, forKey: Key.on); updateMonitors() } }
    var key: HoldKeys { didSet { defaults.set(key.rawValue, forKey: Key.key); taps.reset() } }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let pair: () -> PointerPair
    @ObservationIgnored private let pointerScale: () -> Double
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var taps = DoubleTap()
    @ObservationIgnored private lazy var indicator = LocatorWindow()

    init(defaults: UserDefaults = .standard, pair: @escaping () -> PointerPair, pointerScale: @escaping () -> Double) {
        self.defaults = defaults
        self.pair = pair
        self.pointerScale = pointerScale
        isOn = defaults.bool(forKey: Key.on)
        let saved = HoldKeys(rawValue: defaults.integer(forKey: Key.key))
        key = Self.keys.contains(saved) ? saved : .control
        updateMonitors()
    }

    /// Shows the ring at the pointer now, as a double press does.
    func reveal() {
        indicator.show(at: NSEvent.mouseLocation, pair: pair(), pointerScale: pointerScale())
    }

    private func updateMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        taps.reset()
        guard isOn, !ScreenshotRenderer.isRendering else { return }
        let events: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        let global = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
            return event
        }
        monitors = [global, local].compactMap { $0 }
    }

    private func handle(_ event: NSEvent) {
        guard event.type == .flagsChanged else { return taps.reset() }
        if taps.handle(held: HoldKeys(flags: event.modifierFlags), key: key, at: event.timestamp) { reveal() }
    }

    private enum Key {
        static let on = "pointerLocatorOn"
        static let key = "pointerLocatorKey"
    }
}

/// Two quick presses of one modifier key on its own, within a second.
struct DoubleTap {
    static let longestPress: TimeInterval = 0.35
    static let longestGap: TimeInterval = 1

    private var pressedAt: TimeInterval?
    /// System-wide key presses when the key went down. A different count on release means the key
    /// was part of a shortcut, like ⌃C. Global monitors can't see those keys without Accessibility,
    /// but the count needs no permission.
    private var keyDownsAtPress: UInt32 = 0
    private var firstTapAt: TimeInterval?

    mutating func reset() {
        pressedAt = nil
        firstTapAt = nil
    }

    /// Returns true on the second tap.
    mutating func handle(held: HoldKeys, key: HoldKeys, at time: TimeInterval) -> Bool {
        if let firstTapAt, time - firstTapAt > Self.longestGap { self.firstTapAt = nil }
        if held == key {
            pressedAt = time
            keyDownsAtPress = Self.keyDowns
            return false
        }
        guard held.isEmpty, let pressedAt else { reset(); return false }
        self.pressedAt = nil
        guard time - pressedAt <= Self.longestPress, Self.keyDowns == keyDownsAtPress else { reset(); return false }
        guard firstTapAt != nil else { firstTapAt = time; return false }
        firstTapAt = nil
        return true
    }

    private static var keyDowns: UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }
}

/// A borderless window that shows the closing ring once, then hides.
@MainActor
private final class LocatorWindow {
    private static let side: CGFloat = 200
    private static let duration: CFTimeInterval = 0.8

    private let panel: NSPanel
    private let edge = CAShapeLayer()
    private let ring = CAShapeLayer()
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: Self.side, height: Self.side),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        view.wantsLayer = true
        for layer in [edge, ring] {
            layer.fillColor = nil
            layer.frame = view.bounds
            view.layer?.addSublayer(layer)
        }
        panel.contentView = view
    }

    func show(at point: CGPoint, pair: PointerPair, pointerScale: Double) {
        panel.setFrame(CGRect(x: point.x - Self.side / 2, y: point.y - Self.side / 2, width: Self.side, height: Self.side),
                       display: false)
        let end = 18 + 8 * CGFloat(pointerScale)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start: CGFloat = reduceMotion ? end : 90
        edge.strokeColor = cgColor(pair.outline)
        edge.lineWidth = 7
        ring.strokeColor = cgColor(pair.fill)
        ring.lineWidth = 3
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [edge, ring] {
            layer.path = circle(radius: end)
            layer.opacity = 0
            layer.add(closing(from: circle(radius: start), to: circle(radius: end)), forKey: "close")
        }
        CATransaction.commit()
        panel.orderFrontRegardless()
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration, execute: work)
    }

    /// The ring shrinks onto the pointer, easing out, and fades over the last quarter.
    private func closing(from: CGPath, to: CGPath) -> CAAnimationGroup {
        let path = CABasicAnimation(keyPath: "path")
        path.fromValue = from
        path.toValue = to
        path.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 1, 0.68, 1)
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.75, 1]
        let group = CAAnimationGroup()
        group.animations = [path, fade]
        group.duration = Self.duration
        return group
    }

    private func cgColor(_ color: RGBA) -> CGColor {
        CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func circle(radius: CGFloat) -> CGPath {
        let center = Self.side / 2
        return CGPath(ellipseIn: CGRect(x: center - radius, y: center - radius, width: radius * 2, height: radius * 2),
                      transform: nil)
    }
}
