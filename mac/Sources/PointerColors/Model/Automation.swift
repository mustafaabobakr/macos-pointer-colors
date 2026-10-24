import AppKit
import Observation

/// A connected display, identified by a UUID that survives reboots and replugging.
struct DisplayInfo: Identifiable, Equatable {
    let id: String
    let name: String
    /// The MacBook's own screen.
    let isBuiltIn: Bool

    static func current() -> [DisplayInfo] {
        NSScreen.screens.compactMap(DisplayInfo.init(screen:))
    }

    init?(screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else { return nil }
        id = string
        name = screen.localizedName
        isBuiltIn = CGDisplayIsBuiltin(number.uint32Value) != 0
    }
}

/// What makes an app's own pair apply.
enum AppRuleTrigger: String {
    /// The pointer is over one of the app's windows; the app doesn't need to be in front.
    case pointer
    /// The app is in front.
    case frontmost
}

/// What the window under the pointer means for per-app pairs.
enum PointerTarget: Equatable {
    /// A normal window of this app.
    case app(String)
    /// The desktop: no app.
    case desktop
    /// Menus, the menu bar, the Dock and this app's own windows: keep the previous app.
    case ignored

    init(windowNumber: Int) {
        guard windowNumber > 0 else { self = .desktop; return }
        let list = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(windowNumber)) as? [[String: Any]]
        guard let info = list?.first, let layer = info[kCGWindowLayer as String] as? Int,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t else { self = .ignored; return }
        if layer < 0 { self = .desktop; return }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        guard layer == 0, let bundleID, bundleID != Bundle.main.bundleIdentifier else { self = .ignored; return }
        self = .app(bundleID)
    }
}

/// Things the app does on its own: switching pairs with the system appearance and changing the
/// pointer size when the pointer moves to another display.
@MainActor
@Observable
final class Automation {
    var followsAppearance: Bool {
        didSet { settings.followsAppearance = followsAppearance; applyAppearancePair() }
    }
    var lightPairID: String {
        didSet { settings.lightPairID = lightPairID; applyAppearancePair() }
    }
    var darkPairID: String {
        didSet { settings.darkPairID = darkPairID; applyAppearancePair() }
    }
    var perDisplaySizes: Bool {
        didSet { settings.perDisplaySizes = perDisplaySizes; updatePointerTracking() }
    }
    /// When on, a display can have its own pair; displays without one use the main pair.
    var perDisplayColors: Bool {
        didSet {
            settings.perDisplayColors = perDisplayColors
            updatePointerTracking()
            refreshColors()
        }
    }
    /// When on, an app can have its own pair, applied while the pointer is over it or while it's in
    /// front (see appRuleTrigger). App rules beat display rules.
    var perAppColors: Bool {
        didSet { settings.perAppColors = perAppColors; updatePointerTracking(); refreshColors() }
    }
    var appRuleTrigger: AppRuleTrigger {
        didSet { settings.appRuleTrigger = appRuleTrigger; updatePointerTracking(); refreshColors() }
    }
    /// Pair id per app bundle id.
    private(set) var appPairs: [String: String]
    /// The app in front, ignoring Pointer Colors itself so opening its windows changes nothing.
    private(set) var frontmostBundleID: String?
    /// The app whose window is under the pointer, while app pairs follow the pointer.
    @ObservationIgnored private var hoveredBundleID: String?
    /// The window under the pointer at the last check, so most mouse moves skip the app lookup.
    @ObservationIgnored private var hoveredWindow: Int?
    private(set) var displaySizes: [String: Double]
    /// Pair id per display UUID. A missing entry means "same as all displays".
    private(set) var displayPairs: [String: String]
    private(set) var displays: [DisplayInfo] = DisplayInfo.current()
    /// The display the pointer is on, while the pointer is tracked.
    private(set) var lastDisplayID: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let applyPair: (String) -> Void
    @ObservationIgnored private let applyScale: (Double) -> Void
    /// Puts a pair on screen without making it the main pair.
    @ObservationIgnored private let showPair: (String) -> Void
    /// Puts a display's pair and size on screen in one change. Either may be nil.
    @ObservationIgnored private let showDisplay: (String?, Double?) -> Void
    /// The pair chosen for all displays.
    @ObservationIgnored private let mainPairID: () -> String?
    @ObservationIgnored private var displayTimer: Timer?
    @ObservationIgnored private var pointerMonitors: [Any] = []
    /// The frame of the display the pointer was last seen on, so most mouse moves end at one rect test.
    @ObservationIgnored private var lastScreenFrame: NSRect?

    init(settings: AppSettings,
         applyPair: @escaping (String) -> Void,
         applyScale: @escaping (Double) -> Void,
         showPair: @escaping (String) -> Void,
         showDisplay: @escaping (String?, Double?) -> Void,
         mainPairID: @escaping () -> String?) {
        self.settings = settings
        self.applyPair = applyPair
        self.applyScale = applyScale
        self.showPair = showPair
        self.showDisplay = showDisplay
        self.mainPairID = mainPairID
        followsAppearance = settings.followsAppearance
        lightPairID = settings.lightPairID
        darkPairID = settings.darkPairID
        perDisplaySizes = settings.perDisplaySizes
        perDisplayColors = settings.perDisplayColors
        displaySizes = settings.displaySizes
        displayPairs = settings.displayPairs
        perAppColors = settings.perAppColors
        appRuleTrigger = settings.appRuleTrigger
        appPairs = settings.appPairs
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        observeSystem()
        updatePointerTracking()
    }

    // MARK: Appearance

    var isDarkMode: Bool {
        UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String == "Dark"
    }

    func applyAppearancePair() {
        guard followsAppearance else { return }
        applyPair(isDarkMode ? darkPairID : lightPairID)
    }

    // MARK: Displays

    func size(for display: DisplayInfo) -> Double {
        displaySizes[display.id] ?? SystemPointer.minimumScale
    }

    func setSize(_ size: Double, for display: DisplayInfo) {
        displaySizes[display.id] = size
        settings.displaySizes = displaySizes
        if display.id == lastDisplayID, perDisplaySizes { applyScale(size) }
    }

    var currentDisplay: DisplayInfo? { displays.first { $0.id == lastDisplayID } }

    /// Records the size for the display the pointer is on, without applying it again.
    func rememberSizeForCurrentDisplay(_ size: Double) {
        guard perDisplaySizes, let id = lastDisplayID else { return }
        displaySizes[id] = size
        settings.displaySizes = displaySizes
    }

    /// Back to the default size on every display.
    func resetAllDisplaySizes() {
        displaySizes = [:]
        settings.displaySizes = [:]
    }

    // MARK: Per-display colors

    func pairID(for display: DisplayInfo) -> String? {
        displayPairs[display.id]
    }

    /// Nil goes back to "same as all displays".
    func setPair(_ pairID: String?, for display: DisplayInfo) {
        displayPairs[display.id] = pairID
        settings.displayPairs = displayPairs
        if display.id == lastDisplayID { applyColors(for: display.id) }
    }

    /// Re-applies the rule for the display under the pointer, e.g. after the main pair changed.
    func applyCurrentDisplayColors() {
        applyColors(for: lastDisplayID)
    }

    // MARK: Per-app colors

    /// Apps with their own pair, sorted by bundle id.
    var appRuleIDs: [String] { appPairs.keys.sorted() }

    func pairID(forApp bundleID: String) -> String? { appPairs[bundleID] }

    /// Nil removes the app's rule.
    func setPair(_ pairID: String?, forApp bundleID: String) {
        appPairs[bundleID] = pairID
        settings.appPairs = appPairs
        if bundleID == frontmostBundleID { refreshColors() }
    }

    private func applyColors(for displayID: String?) {
        guard let id = targetPairID(displayID: displayID) else { return }
        showPair(id)
    }

    /// App rule first, then display rule, then the main pair. Nil when no rules are on.
    private func targetPairID(displayID: String?) -> String? {
        guard perAppColors || perDisplayColors else { return nil }
        if perAppColors, let app = ruleAppID, let id = appPairs[app] { return id }
        if perDisplayColors, let displayID, let id = displayPairs[displayID] { return id }
        return mainPairID()
    }

    /// Applies the rules, or the main pair once every rule is off.
    private func refreshColors() {
        if perAppColors || perDisplayColors {
            applyColors(for: lastDisplayID)
        } else if let main = mainPairID() {
            showPair(main)
        }
    }

    /// The app whose rule applies: the one under the pointer or the one in front.
    private var ruleAppID: String? { appRuleTrigger == .pointer ? hoveredBundleID : frontmostBundleID }

    private var followsPointerApp: Bool { perAppColors && appRuleTrigger == .pointer }

    private func frontmostAppChanged(_ app: NSRunningApplication?) {
        // A window can come up under a pointer that hasn't moved.
        if followsPointerApp { pointerMoved() }
        guard let id = app?.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        frontmostBundleID = id
        if perAppColors, appRuleTrigger == .frontmost { applyColors(for: lastDisplayID) }
    }

    private var tracksPointer: Bool { perDisplaySizes || perDisplayColors || followsPointerApp }

    private static let pointerEvents: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged,
                                                               .rightMouseDragged, .otherMouseDragged]

    private func updatePointerTracking() {
        stopPointerTracking()
        guard tracksPointer else { return }
        // Deferred: running it during init would call back into the model before it holds this object.
        DispatchQueue.main.async { [weak self] in self?.pointerMoved() }
        startPointerMonitors()
        // Fallback for changes that send no mouse events, such as a warp by another app or a window
        // moving under a still pointer.
        displayTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
    }

    private func stopPointerTracking() {
        displayTimer?.invalidate()
        displayTimer = nil
        pointerMonitors.forEach(NSEvent.removeMonitor)
        pointerMonitors = []
        lastDisplayID = nil
        lastScreenFrame = nil
        hoveredWindow = nil
        hoveredBundleID = nil
    }

    /// Follows the pointer as it moves, so a display or app change is applied the moment it happens.
    /// The global monitor sees moves over other apps, the local one moves over this app's windows.
    private func startPointerMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.pointerEvents) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.pointerEvents) { [weak self] event in
            MainActor.assumeIsolated { self?.pointerMoved() }
            return event
        }
        pointerMonitors = [global, local].compactMap { $0 }
    }

    /// Runs on every mouse move, so it stays cheap: a window-number lookup and a rect test until
    /// the pointer reaches another app's window or another display.
    private func pointerMoved() {
        let appChanged = followsPointerApp && updateHoveredApp()
        if updatePointerDisplay() {
            showCurrentDisplay()
        } else if appChanged {
            applyColors(for: lastDisplayID)
        }
    }

    /// Notes the app whose window is under the pointer. True when it changed.
    private func updateHoveredApp() -> Bool {
        let window = NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0)
        guard window != hoveredWindow else { return false }
        hoveredWindow = window
        let target = PointerTarget(windowNumber: window)
        guard target != .ignored else { return false }
        let bundleID: String? = if case .app(let id) = target { id } else { nil }
        guard bundleID != hoveredBundleID else { return false }
        hoveredBundleID = bundleID
        return true
    }

    /// Notes the display under the pointer. True when it's another display.
    private func updatePointerDisplay() -> Bool {
        let location = NSEvent.mouseLocation
        if let lastScreenFrame, NSMouseInRect(location, lastScreenFrame, false) { return false }
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }) else { return false }
        lastScreenFrame = screen.frame
        guard let display = DisplayInfo(screen: screen), display.id != lastDisplayID else { return false }
        lastDisplayID = display.id
        return true
    }

    /// Applies the stored size and colors for the display under the pointer.
    private func showCurrentDisplay() {
        guard let id = lastDisplayID else { return }
        showDisplay(targetPairID(displayID: id), perDisplaySizes ? displaySizes[id] : nil)
    }

    // MARK: System notifications

    private func observeSystem() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                          object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.frontmostAppChanged(app) }
        }
        let themeChanged = Notification.Name("AppleInterfaceThemeChangedNotification")
        DistributedNotificationCenter.default().addObserver(forName: themeChanged, object: nil, queue: .main) { [weak self] _ in
            // The new style is written just after the notification; give it a moment.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                MainActor.assumeIsolated { self?.applyAppearancePair() }
            }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.displays = DisplayInfo.current()
                self?.lastDisplayID = nil
                self?.lastScreenFrame = nil
            }
        }
    }
}
