import AppKit
import Observation

/// Focuses the window under the pointer without bringing it to the front, once the pointer rests
/// on it for a moment. Holding a modifier key or a mouse button pauses it, and a window only takes
/// focus once each time the pointer enters it, so a click or ⌘-Tab elsewhere sticks.
@MainActor
@Observable
final class HoverFocus {
    var isOn: Bool { didSet { defaults.set(isOn, forKey: Key.on); update() } }

    /// Seconds the pointer must rest on a window before it takes focus.
    static let delay: TimeInterval = 0.12

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let tap: MouseEventTap
    @ObservationIgnored private let worker = HoverFocusWorker()

    var isAvailable: Bool { WindowFocus.shared.isAvailable }

    init(defaults: UserDefaults = .standard, tap: MouseEventTap = .shared) {
        self.defaults = defaults
        self.tap = tap
        isOn = defaults.bool(forKey: Key.on)
        update()
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
    // Worker-only state.
    private var entries = HoverEntries()
    private let query = WindowQuery()
    private static let pauseFlags: CGEventFlags = [.maskControl, .maskCommand, .maskAlternate, .maskShift]
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    /// A move to `point`, or with nil a click or key press, which ends the current entry.
    func observe(_ point: CGPoint?) {
        lock.withLock {
            self.point = point
            movedAt = ProcessInfo.processInfo.systemUptime
        }
        if point == nil { queue.async { self.entries.consume() } }
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
        let (point, movedAt) = lock.withLock { (self.point, self.movedAt) }
        guard let point, ProcessInfo.processInfo.systemUptime - movedAt >= HoverFocus.delay, isIdle(),
              let window = WindowFocus.shared.window(at: point), window.pid != ownPID,
              entries.enter(window) else { return }
        // The entry is used up whatever happens, so focus is tried once per visit.
        entries.consume()
        guard query.canFocus(window, at: point), let focus = query.currentFocus(), focus != window,
              WindowFocus.shared.window(at: point) == window, isIdle() else { return }
        _ = WindowFocus.shared.focus(window, from: focus)
    }

    /// No modifier key or mouse button is down.
    private func isIdle() -> Bool {
        guard CGEventSource.flagsState(.combinedSessionState).isDisjoint(with: Self.pauseFlags) else { return false }
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
