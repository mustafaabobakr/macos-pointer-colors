import AppKit
import Observation

/// Shrinks the system pointer while a mouse button is down, and grows it back on release, when
/// `shrinksOnPress` is on. How small, how fast and along which curve come from `PointerHighlight`.
///
/// The size steps live through `SystemPointer.showPressed`, once a frame, and is never saved, so the size in Preferences and System Settings stays the same. macOS draws the
/// pointer no smaller than 1×, so at that size a press shows nothing.
@MainActor
final class PressShrink {
    private let settings: PointerHighlight
    private let pointer: SystemPointer
    private var monitors: [Any] = []
    private var timer: Timer?
    /// The size on screen while a press has it changed; nil when it's the saved size.
    private var shown: Double?
    private var isPressed = false

    private static let events: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp]

    init(settings: PointerHighlight, pointer: SystemPointer) {
        self.settings = settings
        self.pointer = pointer
        observeSettings()
        DispatchQueue.main.async { [weak self] in self?.update() }
    }

    /// Puts the saved size back at once, e.g. when the app quits mid-press.
    func restore() {
        timer?.invalidate()
        timer = nil
        isPressed = false
        shown = nil
        pointer.endPress()
    }

    // MARK: On and off

    private func observeSettings() {
        withObservationTracking {
            _ = settings.shrinksOnPress
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.update()
                self?.observeSettings()
            }
        }
    }

    private func update() {
        if settings.shrinksOnPress { start() } else { stop() }
    }

    private func start() {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
            return event
        }
        monitors = [global, local].compactMap { $0 }
    }

    private func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        restore()
    }

    // MARK: Pressing

    private func handle(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown: press(isLeft: true)
        case .rightMouseDown: press(isLeft: false)
        default: release()
        }
    }

    private func press(isLeft: Bool) {
        guard settings.shrinks(isLeft: isLeft) else { return }
        let saved = pointer.currentScale()
        let target = max(saved * settings.pressScale, SystemPointer.minimumScale)
        guard target < saved else { return }
        isPressed = true
        animate(to: target, over: settings.pressDownDuration)
    }

    /// Grows back once every button is up; a release that never reached us is caught by `step`.
    private func release() {
        guard isPressed, NSEvent.pressedMouseButtons == 0 else { return }
        isPressed = false
        animate(to: pointer.currentScale(), over: settings.pressUpDuration)
    }

    private func animate(to target: Double, over duration: TimeInterval) {
        let from = shown ?? pointer.currentScale()
        let start = CACurrentMediaTime()
        let curve = settings.pressCurve
        schedule(every: 1.0 / 60) { [weak self] in
            MainActor.assumeIsolated {
                let progress = duration > 0 ? min((CACurrentMediaTime() - start) / duration, 1) : 1
                self?.step(to: from + (target - from) * curve.value(at: progress), done: progress >= 1)
            }
        }
        timer?.fire()
    }

    /// Runs `tick` in every run loop mode: while the button is down in this app's own windows,
    /// like the demo pad in Preferences, the run loop is tracking the mouse and skips plain timers.
    private func schedule(every interval: TimeInterval, _ tick: @escaping @Sendable () -> Void) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { _ in tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Shows one frame. Once a grow-back lands, the press is over; a shrink keeps the timer,
    /// slowed down, to watch for a release that never arrived.
    private func step(to size: Double, done: Bool) {
        let scale = max(size, SystemPointer.minimumScale)
        shown = scale
        pointer.showPressed(scale)
        guard done else { return }
        if isPressed { return watchForLostRelease() }
        restore()
    }

    private func watchForLostRelease() {
        schedule(every: 0.25) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, NSEvent.pressedMouseButtons == 0 else { return }
                self.release()
            }
        }
    }
}
