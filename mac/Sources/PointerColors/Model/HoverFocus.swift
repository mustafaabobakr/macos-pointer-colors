import AppKit
import Observation

/// Focuses the window under the pointer without bringing it to the front, once the pointer rests
/// on it for a moment. Holding a modifier key or a mouse button pauses it, and a window only takes
/// focus once each time the pointer enters it, so a click or ⌘-Tab elsewhere sticks.
@MainActor
@Observable
final class HoverFocus {
    var isOn: Bool { didSet { defaults.set(isOn, forKey: Key.on); update() } }

    /// Seconds the pointer must rest on a window before it takes focus, in hundredths.
    var delay: TimeInterval { didSet { delayChanged() } }
    /// The modifier keys that pause focusing while held.
    var pauseKeys: HoverPauseKeys {
        didSet { defaults.set(pauseKeys.rawValue, forKey: Key.pauseKeys); configureWorker() }
    }

    static let defaultDelay: TimeInterval = 0.12
    static let delayRange: ClosedRange<TimeInterval> = 0.05...1

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let tap: MouseEventTap
    @ObservationIgnored private let worker = HoverFocusWorker()

    var isAvailable: Bool { WindowFocus.shared.isAvailable }

    init(defaults: UserDefaults = .standard, tap: MouseEventTap = .shared) {
        self.defaults = defaults
        self.tap = tap
        isOn = defaults.bool(forKey: Key.on)
        delay = Self.snapped((defaults.object(forKey: Key.delay) as? Double) ?? Self.defaultDelay)
        pauseKeys = (defaults.object(forKey: Key.pauseKeys) as? Int).map(HoverPauseKeys.init(saved:)) ?? .all
        configureWorker()
        update()
    }

    /// `seconds` in the slider's range, to the hundredth.
    static func snapped(_ seconds: TimeInterval) -> TimeInterval {
        (seconds.clamped(to: delayRange) * 100).rounded() / 100
    }

    /// Snaps the delay, then saves it. The snapping assignment runs this again, so it saves only
    /// once the value is already snapped, and never recurses further.
    private func delayChanged() {
        let snapped = Self.snapped(delay)
        guard delay == snapped else { delay = snapped; return }
        defaults.set(delay, forKey: Key.delay)
        configureWorker()
    }

    private func configureWorker() {
        worker.configure(delay: delay, pauseFlags: pauseKeys.flags)
    }

    private func update() {
        let on = isOn && isAvailable
        worker.setRunning(on)
        tap.set(Key.on, types: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown],
                handler: on ? { [worker] type, event in
                    worker.observe(type == .mouseMoved ? event.location : nil)
                    return .pass
                } : nil)
    }

    private enum Key {
        static let on = "hoverFocusOn"
        static let delay = "hoverFocusDelay"
        static let pauseKeys = "hoverFocusPauseKeys"
    }
}

/// Does the window lookups and focusing off the main thread, which the event tap runs on: a slow
/// app's Accessibility answer must never hold up the mouse.
final class HoverFocusWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "PointerColors.hover-focus", qos: .userInitiated)
    private let lock = NSLock()
    private var point: CGPoint?
    private var movedAt: TimeInterval = 0
    private var timer: DispatchSourceTimer?
    private var delay: TimeInterval = 0
    private var pauseFlags: CGEventFlags = []
    // Worker-only state.
    private var entries = HoverEntries()
    private let query = WindowQuery()
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// A move to `point`, or with nil a click or key press, which ends the current entry.
    func observe(_ point: CGPoint?) {
        lock.withLock {
            self.point = point
            movedAt = ProcessInfo.processInfo.systemUptime
        }
        if point == nil { queue.async { self.entries.consume() } }
    }

    /// The rest time and the keys that pause focusing, from Preferences.
    func configure(delay: TimeInterval, pauseFlags: CGEventFlags) {
        lock.withLock {
            self.delay = delay
            self.pauseFlags = pauseFlags
        }
    }

    func setRunning(_ running: Bool) {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            entries = HoverEntries()
            guard running else { return }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(40), leeway: .milliseconds(10))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer
            timer.resume()
        }
    }

    private func poll() {
        guard let resting = restingPoint() else { return }
        let (point, pauseFlags) = resting
        guard let window = WindowFocus.shared.window(at: point), window.pid != ownPID,
              entries.enter(window) else { return }
        // The entry is used up whatever happens, so focus is tried once per visit.
        entries.consume()
        guard query.canFocus(window, at: point), let focus = query.currentFocus(), focus != window,
              WindowFocus.shared.window(at: point) == window, isIdle(pauseFlags) else { return }
        _ = WindowFocus.shared.focus(window, from: focus)
    }

    /// Where the pointer has rested for the delay with nothing held, and the keys that pause focusing.
    private func restingPoint() -> (point: CGPoint, pauseFlags: CGEventFlags)? {
        let (point, movedAt, delay, pauseFlags) = lock.withLock { (self.point, self.movedAt, self.delay, self.pauseFlags) }
        guard let point, ProcessInfo.processInfo.systemUptime - movedAt >= delay, isIdle(pauseFlags) else { return nil }
        return (point, pauseFlags)
    }

    /// No pausing modifier key or mouse button is down.
    private func isIdle(_ pauseFlags: CGEventFlags) -> Bool {
        guard CGEventSource.flagsState(.combinedSessionState).isDisjoint(with: pauseFlags) else { return false }
        return !(0..<8).contains { CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: $0)!) }
    }
}

/// The window the pointer is in, and whether its one focus attempt is still to come.
struct HoverEntries {
    private(set) var window: WindowFocus.Target?
    private var used = false

    /// The pointer is over `window`. True while this visit hasn't tried to focus it yet.
    mutating func enter(_ window: WindowFocus.Target) -> Bool {
        if window != self.window {
            self.window = window
            used = false
        }
        return !used
    }

    mutating func consume() { used = true }
}
