import AppKit
import Carbon.HIToolbox
import Observation

/// The mouse's side buttons go back and forward, and a worn button's extra clicks are dropped.
/// Both watch clicks through `MouseEventTap`, so they need Accessibility.
@MainActor
@Observable
final class MouseButtons {
    /// Side buttons go back and forward in Safari, Finder and other apps that ignore them.
    var sideButtonsNavigate: Bool { didSet { defaults.set(sideButtonsNavigate, forKey: Key.sideButtons); update() } }
    /// Swiping sideways on a Magic Mouse presses a listed app's back and forward keys.
    var swipesNavigate: Bool { didSet { defaults.set(swipesNavigate, forKey: Key.swipesOn); update() } }
    /// Points sideways a Magic Mouse swipe must travel to go back or forward.
    var swipeDistance: Double {
        didSet {
            let snapped = Self.snappedDistance(swipeDistance)
            // Assigning re-enters didSet; the guard stops it there.
            guard swipeDistance == snapped else { swipeDistance = snapped; return }
            defaults.set(swipeDistance, forKey: Key.swipeDistance)
            swipes.distance = swipeDistance
        }
    }
    /// The button numbers, as macOS counts them from 0, that go back and forward.
    private(set) var backButton: Int64 { didSet { defaults.set(backButton, forKey: Key.backButton); sideButtons.back = backButton } }
    private(set) var forwardButton: Int64 { didSet { defaults.set(forwardButton, forKey: Key.forwardButton); sideButtons.forward = forwardButton } }
    /// Apps that go back and forward with their own keys, like Slack's ⌘[ and ⌘].
    var navigationApps: [NavigationApp] {
        didSet {
            defaults.set(try? JSONEncoder().encode(navigationApps), forKey: Key.navigationApps)
            sideButtons.apps = navigationApps
            swipes.apps = navigationApps
        }
    }
    /// Drops a click that comes too soon after the last one, as a worn switch makes.
    var fixesDoubleClicks: Bool { didSet { defaults.set(fixesDoubleClicks, forKey: Key.debounce); update() } }
    /// Seconds a new press must wait after a release to count.
    var doubleClickWindow: Double {
        didSet { defaults.set(doubleClickWindow, forKey: Key.debounceWindow); debouncers = [:] }
    }
    /// The buttons the double-click fix watches.
    var doubleClickButtons: DoubleClickButtons {
        didSet { defaults.set(doubleClickButtons.rawValue, forKey: Key.debounceButtons); debouncers = [:]; update() }
    }

    static let doubleClickWindowRange = 0.01...0.15
    nonisolated static let swipeDistanceRange = 40.0...200.0
    nonisolated static let swipeDistanceStep = 10.0
    nonisolated static let defaultSwipeDistance = 80.0
    /// Buttons 4 and 5 to people, the usual side buttons.
    nonisolated static let defaultBackButton: Int64 = 3
    nonisolated static let defaultForwardButton: Int64 = 4

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let tap: MouseEventTap
    @ObservationIgnored private var sideButtons = SideButtonNavigation()
    @ObservationIgnored private var swipes = SwipeNavigation()
    @ObservationIgnored private var debouncers: [Int64: ClickDebouncer] = [:]

    init(defaults: UserDefaults = .standard, tap: MouseEventTap = .shared) {
        self.defaults = defaults
        self.tap = tap
        sideButtonsNavigate = defaults.bool(forKey: Key.sideButtons)
        swipesNavigate = Self.storedSwipesNavigate(in: defaults)
        swipeDistance = Self.snappedDistance(defaults.object(forKey: Key.swipeDistance) as? Double ?? Self.defaultSwipeDistance)
        backButton = Self.storedButton(Key.backButton, in: defaults) ?? Self.defaultBackButton
        forwardButton = Self.storedButton(Key.forwardButton, in: defaults) ?? Self.defaultForwardButton
        navigationApps = Self.storedNavigationApps(in: defaults)
        fixesDoubleClicks = defaults.bool(forKey: Key.debounce)
        doubleClickWindow = defaults.object(forKey: Key.debounceWindow) as? Double ?? 0.05
        doubleClickButtons = defaults.string(forKey: Key.debounceButtons).flatMap(DoubleClickButtons.init) ?? .leftAndRight
        sideButtons.apps = navigationApps
        sideButtons.back = backButton
        sideButtons.forward = forwardButton
        swipes.apps = navigationApps
        swipes.distance = swipeDistance
        update()
    }

    /// Adds the app at `url`, with no keys yet, unless it's in the list already.
    func addNavigationApp(at url: URL) {
        guard let app = NavigationApp(url: url), !navigationApps.contains(where: { $0.id == app.id }) else { return }
        navigationApps.append(app)
    }

    /// Changes the listed app with `id`, if it's still there.
    func changeNavigationApp(_ id: NavigationApp.ID, _ change: (inout NavigationApp) -> Void) {
        guard let index = navigationApps.firstIndex(where: { $0.id == id }) else { return }
        change(&navigationApps[index])
    }

    func removeNavigationApp(_ id: NavigationApp.ID) {
        navigationApps.removeAll { $0.id == id }
    }

    /// Makes `number` go back; if it went forward, forward takes the old back button, so they swap.
    func setBackButton(_ number: Int64) {
        if number == forwardButton { forwardButton = backButton }
        backButton = number
    }

    /// Makes `number` go forward; if it went back, back takes the old forward button, so they swap.
    func setForwardButton(_ number: Int64) {
        if number == backButton { backButton = forwardButton }
        forwardButton = number
    }

    /// Back to buttons 4 and 5.
    func resetNavigationButtons() {
        backButton = Self.defaultBackButton
        forwardButton = Self.defaultForwardButton
    }

    /// Within the range, on a whole step. Never assign the result back unless it differs.
    static func snappedDistance(_ value: Double) -> Double {
        let clamped = min(max(value, swipeDistanceRange.lowerBound), swipeDistanceRange.upperBound)
        return (clamped / swipeDistanceStep).rounded() * swipeDistanceStep
    }

    /// The swipe once followed the side-buttons switch, so a Mac that never saved its own switch
    /// keeps doing what it did. Saved at once, so turning the side buttons off later leaves it alone.
    private static func storedSwipesNavigate(in defaults: UserDefaults) -> Bool {
        if let saved = defaults.object(forKey: Key.swipesOn) as? Bool { return saved }
        let followed = defaults.bool(forKey: Key.sideButtons)
        defaults.set(followed, forKey: Key.swipesOn)
        return followed
    }

    /// A saved button number, or nil when there's none or it's a left or right click.
    private static func storedButton(_ key: String, in defaults: UserDefaults) -> Int64? {
        guard let number = defaults.object(forKey: key) as? Int, number >= 2 else { return nil }
        return Int64(number)
    }

    /// The saved list, with any built-in app it hasn't had before put at the end, and Finder first.
    /// Each is added once, so one that was removed stays removed. An app that isn't installed is
    /// listed anyway: nothing has its bundle ID, so its keys are never pressed.
    private static func storedNavigationApps(in defaults: UserDefaults) -> [NavigationApp] {
        var apps = defaults.data(forKey: Key.navigationApps)
            .flatMap { try? JSONDecoder().decode([NavigationApp].self, from: $0) } ?? []
        var offered = Set(defaults.stringArray(forKey: Key.offeredApps) ?? [])
        let added = NavigationApp.defaults.filter { app in
            !offered.contains(app.bundleID) && !apps.contains { $0.id == app.id }
        }
        let saved = apps
        apps += added
        apps = apps.filter(\.isFinder) + apps.filter { !$0.isFinder }
        offered.formUnion(apps.map(\.bundleID).filter { id in NavigationApp.defaults.contains { $0.bundleID == id } })
        defaults.set(offered.sorted(), forKey: Key.offeredApps)
        if apps != saved { defaults.set(try? JSONEncoder().encode(apps), forKey: Key.navigationApps) }
        return apps
    }

    private func update() {
        tap.set(Key.sideButtons, types: [.otherMouseDown, .otherMouseUp],
                handler: sideButtonsNavigate ? { [weak self] in self?.sideButtons.handle($0, $1) ?? .pass } : nil)
        tap.set(Key.swipes, types: [.scrollWheel],
                handler: swipesNavigate ? { [weak self] in self?.swipes.handle($1) ?? .pass } : nil)
        tap.set(Key.debounce, types: doubleClickButtons.eventTypes,
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
        static let navigationApps = "sideButtonApps"
        /// Built-in apps the list has had the chance to include, so a removed one isn't added back.
        static let offeredApps = "sideButtonAppsOffered"
        static let swipes = "swipeNavigate"
        static let debounce = "fixesDoubleClicks"
        static let debounceWindow = "doubleClickWindow"
        static let swipesOn = "magicMouseSwipeNavigates"
        static let swipeDistance = "magicMouseSwipeDistance"
        static let backButton = "backMouseButton"
        static let forwardButton = "forwardMouseButton"
        static let debounceButtons = "doubleClickFixButtons"
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

/// An app whose back and forward are keys, so the side buttons press them there.
struct NavigationApp: Codable, Identifiable, Equatable {
    var bundleID: String
    var name: String
    var back: KeyCombo?
    var forward: KeyCombo?
    /// Off keeps the app in the list but leaves its buttons and swipes alone.
    var isOn = true

    var id: String { bundleID }
    var isFinder: Bool { bundleID == "com.apple.finder" }

    /// Slack goes back with ⌘[ and ignores both the buttons and the swipe. Finder's Go menu
    /// has the same keys, which work wherever the swipe doesn't, and so does the Claude app.
    static let defaults = [
        NavigationApp(bundleID: "com.apple.finder", name: "Finder",
                      back: KeyCombo(keyCode: kVK_ANSI_LeftBracket, carbonModifiers: cmdKey, keyLabel: "["),
                      forward: KeyCombo(keyCode: kVK_ANSI_RightBracket, carbonModifiers: cmdKey, keyLabel: "]")),
        NavigationApp(bundleID: "com.anthropic.claudefordesktop", name: "Claude",
                      back: KeyCombo(keyCode: kVK_ANSI_LeftBracket, carbonModifiers: cmdKey, keyLabel: "["),
                      forward: KeyCombo(keyCode: kVK_ANSI_RightBracket, carbonModifiers: cmdKey, keyLabel: "]")),
        NavigationApp(bundleID: "com.tinyspeck.slackmacgap", name: "Slack",
                      back: KeyCombo(keyCode: kVK_ANSI_LeftBracket, carbonModifiers: cmdKey, keyLabel: "["),
                      forward: KeyCombo(keyCode: kVK_ANSI_RightBracket, carbonModifiers: cmdKey, keyLabel: "]")),
    ]

    init(bundleID: String, name: String, back: KeyCombo? = nil, forward: KeyCombo? = nil) {
        self.bundleID = bundleID
        self.name = name
        self.back = back
        self.forward = forward
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try container.decode(String.self, forKey: .bundleID)
        name = try container.decode(String.self, forKey: .name)
        back = try container.decodeIfPresent(KeyCombo.self, forKey: .back)
        forward = try container.decodeIfPresent(KeyCombo.self, forKey: .forward)
        isOn = try container.decodeIfPresent(Bool.self, forKey: .isOn) ?? true
    }

    init?(url: URL) {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        self.init(bundleID: bundleID, name: name)
    }
}

/// Turns the back and forward side buttons into the two-finger swipe that Safari, Finder and
/// Apple's other apps go back and forward with, or into the keys of an app in `apps`. Apps that
/// handle the buttons themselves, like Chrome, get the buttons as they are.
struct SideButtonNavigation {
    var back = MouseButtons.defaultBackButton
    var forward = MouseButtons.defaultForwardButton
    /// Apps that ignore side buttons but follow a navigation swipe. A trailing * matches a prefix.
    static let apps = ["com.apple.*", "org.mozilla.firefox", "com.operasoftware.Opera", "com.binarynights.ForkLift*"]

    /// Apps that go back and forward with keys, which win over the swipe.
    var apps: [NavigationApp] = []
    /// Buttons whose press became a swipe or keys, so their release is dropped too.
    private var swallowed: Set<Int64> = []

    static func navigates(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return apps.contains { $0.hasSuffix("*") ? bundleID.hasPrefix($0.dropLast()) : bundleID == $0 }
    }

    mutating func handle(_ type: CGEventType, _ event: CGEvent) -> MouseEventTap.Verdict {
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        guard button == back || button == forward else { return .pass }
        if type == .otherMouseUp { return swallowed.remove(button) == nil ? .pass : .drop }
        guard navigate(back: button == back, for: Self.app(for: event)) else { return .pass }
        swallowed.insert(button)
        return .drop
    }

    /// Goes back or forward in `app` with its keys or the swipe; false when it does neither.
    private func navigate(back: Bool, for app: NSRunningApplication?) -> Bool {
        guard let app else { return false }
        if let listed = apps.first(where: { $0.isOn && $0.bundleID == app.bundleIdentifier }) {
            guard let combo = back ? listed.back : listed.forward else { return false }
            NavigationKeys.post(combo, to: app)
            return true
        }
        guard Self.navigates(app.bundleIdentifier) else { return false }
        NavigationSwipe.post(back: back)
        return true
    }

    /// The app owning the window under the pointer, or else the one the event goes to, which is
    /// the active app rather than a window in the background or on another display.
    static func app(for event: CGEvent) -> NSRunningApplication? {
        let target = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        let pid = WindowServer.owner(at: event.location) ?? (target > 0 ? target : nil)
        return pid.flatMap { NSRunningApplication(processIdentifier: $0) }
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

/// The Magic Mouse's swipe between pages, a sideways scroll, pressing the back and forward keys of
/// an app in `apps`, which ignores the swipe. Once per swipe; the scroll still reaches the app.
struct SwipeNavigation {
    var apps: [NavigationApp] = []
    /// Points sideways a swipe must travel to count.
    var distance = MouseButtons.defaultSwipeDistance
    private var travelled = (x: 0.0, y: 0.0)
    private var hasFired = false

    mutating func handle(_ event: CGEvent) -> MouseEventTap.Verdict {
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        // Momentum after the finger lifts, and wheel mice, have no phase.
        guard phase != 0 else { return .pass }
        if phase == 1 || phase == 128 { travelled = (0, 0); hasFired = false }
        travelled.x += event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        travelled.y += event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        guard !hasFired, abs(travelled.x) > distance, abs(travelled.x) > 2 * abs(travelled.y) else { return .pass }
        hasFired = true
        fire(back: travelled.x > 0, in: SideButtonNavigation.app(for: event))
        return .pass
    }

    private func fire(back: Bool, in app: NSRunningApplication?) {
        guard let app, let listed = apps.first(where: { $0.isOn && $0.bundleID == app.bundleIdentifier }),
              let combo = back ? listed.back : listed.forward else { return }
        NavigationKeys.post(combo, to: app)
    }
}

/// An app's own back or forward shortcut, pressed and released.
/// Apps like Slack only take keys while they're active, unlike Safari's swipe, so an app in the
/// background is brought forward first, as a click on it would.
enum NavigationKeys {
    static func post(_ combo: KeyCombo, to app: NSRunningApplication) {
        guard !app.isActive else { return press(combo) }
        // macOS ignores activate() from a background app; Accessibility can still bring it forward.
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { press(combo) }
    }

    /// Presses the keys in whatever app is active, as typing them would.
    private static func press(_ combo: KeyCombo) {
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(combo.keyCode), keyDown: isDown) else { return }
            event.flags = combo.eventFlags
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
