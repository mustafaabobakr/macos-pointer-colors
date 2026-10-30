import AppKit
import Observation

/// The mouse's side buttons go back and forward, and a worn button's extra clicks are dropped.
/// Both watch clicks through `MouseEventTap`, so they need Accessibility.
@MainActor
@Observable
final class MouseButtons {
    /// Side buttons go back and forward in Safari, Finder and other apps that ignore them.
    var sideButtonsNavigate: Bool { didSet { defaults.set(sideButtonsNavigate, forKey: Key.sideButtons); update() } }
    /// Drops a click that comes too soon after the last one, as a worn switch makes.
    var fixesDoubleClicks: Bool { didSet { defaults.set(fixesDoubleClicks, forKey: Key.debounce); update() } }
    /// Seconds a new press must wait after a release to count.
    var doubleClickWindow: Double {
        didSet { defaults.set(doubleClickWindow, forKey: Key.debounceWindow); debouncers = [:] }
    }

    static let doubleClickWindowRange = 0.01...0.15

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let tap: MouseEventTap
    @ObservationIgnored private var sideButtons = SideButtonNavigation()
    @ObservationIgnored private var debouncers: [Int64: ClickDebouncer] = [:]

    init(defaults: UserDefaults = .standard, tap: MouseEventTap = .shared) {
        self.defaults = defaults
        self.tap = tap
        sideButtonsNavigate = defaults.bool(forKey: Key.sideButtons)
        fixesDoubleClicks = defaults.bool(forKey: Key.debounce)
        doubleClickWindow = defaults.object(forKey: Key.debounceWindow) as? Double ?? 0.05
        update()
    }

    private func update() {
        tap.set(Key.sideButtons, types: [.otherMouseDown, .otherMouseUp],
                handler: sideButtonsNavigate ? { [weak self] in self?.sideButtons.handle($0, $1) ?? .pass } : nil)
        tap.set(Key.debounce, types: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp],
                handler: fixesDoubleClicks ? { [weak self] in self?.debounce($0, $1) ?? .pass } : nil)
    }

    private func debounce(_ type: CGEventType, _ event: CGEvent) -> MouseEventTap.Verdict {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        let time = Double(event.timestamp) / 1_000_000_000
        var debouncer = debouncers[button] ?? ClickDebouncer(window: doubleClickWindow)
        let isDown = type == .leftMouseDown || type == .rightMouseDown
        let keeps = isDown ? debouncer.press(at: time) : debouncer.release(at: time)
        debouncers[button] = debouncer
        return keeps ? .pass : .drop
    }

    private enum Key {
        static let sideButtons = "sideButtonsNavigate"
        static let debounce = "fixesDoubleClicks"
        static let debounceWindow = "doubleClickWindow"
    }
}

/// Drops a press that comes within `window` seconds of the last release, and the release that
/// goes with it, so an app sees one clean click.
struct ClickDebouncer {
    let window: TimeInterval
    private var lastRelease: TimeInterval?
    private var dropsNextRelease = false

    init(window: TimeInterval) { self.window = window }

    /// False when this press is a bounce to drop.
    mutating func press(at time: TimeInterval) -> Bool {
        guard let lastRelease, time - lastRelease < window else { return true }
        dropsNextRelease = true
        return false
    }

    /// False when this release belongs to a dropped press.
    mutating func release(at time: TimeInterval) -> Bool {
        lastRelease = time
        guard dropsNextRelease else { return true }
        dropsNextRelease = false
        return false
    }
}

/// Turns the back and forward side buttons into the two-finger swipe that Safari, Finder and
/// Apple's other apps go back and forward with. Apps that handle the buttons themselves, like
/// Chrome, get the buttons as they are.
struct SideButtonNavigation {
    static let back: Int64 = 3
    static let forward: Int64 = 4
    /// Apps that ignore side buttons but follow a navigation swipe. A trailing * matches a prefix.
    static let apps = ["com.apple.*", "org.mozilla.firefox", "com.operasoftware.Opera", "com.binarynights.ForkLift*"]

    /// Buttons whose press became a swipe, so their release is dropped too.
    private var swallowed: Set<Int64> = []

    static func navigates(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return apps.contains { $0.hasSuffix("*") ? bundleID.hasPrefix($0.dropLast()) : bundleID == $0 }
    }

    mutating func handle(_ type: CGEventType, _ event: CGEvent) -> MouseEventTap.Verdict {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        guard button == Self.back || button == Self.forward else { return .pass }
        if type == .otherMouseUp { return swallowed.remove(button) == nil ? .pass : .drop }
        guard Self.navigates(Self.bundleID(for: event)) else { return .pass }
        swallowed.insert(button)
        NavigationSwipe.post(back: button == Self.back)
        return .drop
    }

    /// The app the click goes to, or the app owning the window under the pointer.
    private static func bundleID(for event: CGEvent) -> String? {
        let target = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        let pid = target > 0 ? target : WindowServer.owner(at: event.location)
        return pid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }
    }
}

/// The trackpad's two-finger back and forward swipe, posted as a pair of gesture events.
enum NavigationSwipe {
    private static let gestureType = CGEventType(rawValue: UInt32(NSEvent.EventType.gesture.rawValue))!
    private static let hidTypeField = CGEventField(rawValue: 110)!
    private static let phaseField = CGEventField(rawValue: 132)!
    private static let swipeField = CGEventField(rawValue: 115)!
    private static let navigationSwipe: Int64 = 16
    private static let began: Int64 = 1
    private static let ended: Int64 = 4
    private static let left: Int64 = 0x04
    private static let right: Int64 = 0x08

    static func post(back: Bool) {
        for phase in [began, ended] {
            guard let event = CGEvent(source: nil) else { return }
            event.type = gestureType
            event.setIntegerValueField(hidTypeField, value: navigationSwipe)
            event.setIntegerValueField(phaseField, value: phase)
            if phase == began { event.setIntegerValueField(swipeField, value: back ? left : right) }
            event.setIntegerValueField(.eventSourceUserData, value: MouseEventTap.syntheticMarker)
            event.post(tap: .cgSessionEventTap)
        }
    }
}

/// The window under a point, from the list of windows on screen.
enum WindowServer {
    /// The process owning the topmost normal window at `point`, in global top-left coordinates.
    static func owner(at point: CGPoint) -> pid_t? {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.first { window in
            guard window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
            return rect.contains(point)
        }?[kCGWindowOwnerPID as String] as? pid_t
    }
}
