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

    /// Seconds the ring takes to close in, snapped to tenths.
    var duration: Double {
        didSet {
            let snapped = Self.snap(duration, step: 0.1, in: LocatorLook.durationRange)
            guard duration == snapped else { duration = snapped; return }
            defaults.set(duration, forKey: Key.duration)
        }
    }

    /// The ring's radius when it appears, in points, snapped to 5 pt.
    var startRadius: Double {
        didSet {
            let snapped = Self.snap(startRadius, step: 5, in: LocatorLook.startRadiusRange)
            guard startRadius == snapped else { startRadius = snapped; return }
            defaults.set(startRadius, forKey: Key.startRadius)
        }
    }

    /// How large the ring ends around the pointer, as a share of its usual size.
    var endSize: Double {
        didSet {
            let snapped = Self.snap(endSize, step: 0.1, in: LocatorLook.endSizeRange)
            guard endSize == snapped else { endSize = snapped; return }
            defaults.set(endSize, forKey: Key.endSize)
        }
    }

    /// How thick both rings are, as a share of their usual widths.
    var lineWidth: Double {
        didSet {
            let snapped = Self.snap(lineWidth, step: 0.1, in: LocatorLook.lineWidthRange)
            guard lineWidth == snapped else { lineWidth = snapped; return }
            defaults.set(lineWidth, forKey: Key.lineWidth)
        }
    }

    /// The longest time between the two presses, in seconds, snapped to 0.05 s.
    var pressGap: Double {
        didSet {
            let snapped = Self.snap(pressGap, step: 0.05, in: DoubleTap.gapRange)
            guard pressGap == snapped else { pressGap = snapped; return }
            defaults.set(pressGap, forKey: Key.pressGap)
            taps.longestGap = pressGap
        }
    }

    /// The ring as the settings above draw it.
    var look: LocatorLook {
        LocatorLook(duration: duration, startRadius: startRadius, endSize: endSize, lineWidth: lineWidth)
    }

    /// The pointer's size now, for the ring's end size.
    var currentPointerScale: Double { pointerScale() }
    /// The pair the ring is drawn in now.
    var currentPair: PointerPair { pair() }

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
        duration = Self.number(defaults, Key.duration, LocatorLook.defaultDuration, LocatorLook.durationRange)
        startRadius = Self.number(defaults, Key.startRadius, LocatorLook.defaultStartRadius, LocatorLook.startRadiusRange)
        endSize = Self.number(defaults, Key.endSize, 1, LocatorLook.endSizeRange)
        lineWidth = Self.number(defaults, Key.lineWidth, 1, LocatorLook.lineWidthRange)
        pressGap = Self.number(defaults, Key.pressGap, DoubleTap.defaultGap, DoubleTap.gapRange)
        taps.longestGap = pressGap
        updateMonitors()
    }

    /// Shows the ring at the pointer now, as a double press does.
    func reveal() {
        indicator.show(at: NSEvent.mouseLocation, pair: pair(), pointerScale: pointerScale(), look: look)
    }

    /// Rounds to the nearest step, inside the range.
    nonisolated static func snap(_ value: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        ((value / step).rounded() * step).clamped(to: range)
    }

    /// A saved number, or the default when there is none, kept inside the range.
    private static func number(_ defaults: UserDefaults, _ key: String, _ fallback: Double,
                               _ range: ClosedRange<Double>) -> Double {
        ((defaults.object(forKey: key) as? NSNumber)?.doubleValue ?? fallback).clamped(to: range)
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
        static let duration = "pointerLocatorDuration"
        static let startRadius = "pointerLocatorStartRadius"
        static let endSize = "pointerLocatorEndSize"
        static let lineWidth = "pointerLocatorLineWidth"
        static let pressGap = "pointerLocatorPressGap"
    }
}

/// Two quick presses of one modifier key on its own, at most `longestGap` apart (a second unless changed).
struct DoubleTap {
    static let longestPress: TimeInterval = 0.35
    static let defaultGap: TimeInterval = 1
    static let gapRange: ClosedRange<TimeInterval> = 0.3...1.5

    var longestGap = Self.defaultGap

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
        if let firstTapAt, time - firstTapAt > longestGap { self.firstTapAt = nil }
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
    /// The window's side before the first show; each show sizes it to that ring.
    private static let initialSide: CGFloat = 200

    private let panel: NSPanel
    private let edge = CAShapeLayer()
    private let ring = CAShapeLayer()
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: Self.initialSide, height: Self.initialSide),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(frame: CGRect(x: 0, y: 0, width: Self.initialSide, height: Self.initialSide))
        view.wantsLayer = true
        for layer in [edge, ring] {
            layer.fillColor = nil
            layer.frame = view.bounds
            view.layer?.addSublayer(layer)
        }
        panel.contentView = view
    }

    func show(at point: CGPoint, pair: PointerPair, pointerScale: Double, look: LocatorLook) {
        let side = look.side(pointerScale: pointerScale)
        panel.setFrame(CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side), display: false)
        let end = look.endRadius(pointerScale: pointerScale)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let start = look.startRadius(pointerScale: pointerScale, reduceMotion: reduceMotion)
        edge.strokeColor = cgColor(pair.outline)
        edge.lineWidth = look.outlineWidth
        ring.strokeColor = cgColor(pair.fill)
        ring.lineWidth = look.fillWidth
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for layer in [edge, ring] {
            layer.frame = CGRect(x: 0, y: 0, width: side, height: side)
            layer.path = circle(radius: end, side: side)
            layer.opacity = 0
            layer.add(closing(from: circle(radius: start, side: side), to: circle(radius: end, side: side),
                              duration: look.duration), forKey: "close")
        }
        CATransaction.commit()
        panel.orderFrontRegardless()
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + look.duration, execute: work)
    }

    /// The ring shrinks onto the pointer, easing out, and fades over the last quarter.
    private func closing(from: CGPath, to: CGPath, duration: CFTimeInterval) -> CAAnimationGroup {
        let path = CABasicAnimation(keyPath: "path")
        path.fromValue = from
        path.toValue = to
        let (first, second) = LocatorLook.closingCurve
        path.timingFunction = CAMediaTimingFunction(controlPoints: Float(first.x), Float(first.y),
                                                    Float(second.x), Float(second.y))
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, NSNumber(value: LocatorLook.fadeStart), 1]
        let group = CAAnimationGroup()
        group.animations = [path, fade]
        group.duration = duration
        return group
    }

    private func cgColor(_ color: RGBA) -> CGColor {
        CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private func circle(radius: CGFloat, side: CGFloat) -> CGPath {
        let center = side / 2
        return CGPath(ellipseIn: CGRect(x: center - radius, y: center - radius, width: radius * 2, height: radius * 2),
                      transform: nil)
    }
}
