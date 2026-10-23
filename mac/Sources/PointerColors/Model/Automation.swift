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
        didSet { settings.perDisplaySizes = perDisplaySizes; updateDisplayTracking() }
    }
    /// When on, a display can have its own pair; displays without one use the main pair.
    var perDisplayColors: Bool {
        didSet {
            settings.perDisplayColors = perDisplayColors
            updateDisplayTracking()
            refreshColors()
        }
    }
    /// When on, an app can have its own pair, applied while it's in front. App rules beat display rules.
    var perAppColors: Bool {
        didSet { settings.perAppColors = perAppColors; refreshColors() }
    }
    /// Pair id per app bundle id.
    private(set) var appPairs: [String: String]
    /// The app in front, ignoring Pointer Colors itself so opening its windows changes nothing.
    private(set) var frontmostBundleID: String?
    private(set) var displaySizes: [String: Double]
    /// Pair id per display UUID. A missing entry means "same as all displays".
    private(set) var displayPairs: [String: String]
    private(set) var displays: [DisplayInfo] = DisplayInfo.current()
    /// The display the pointer is on, while per-display sizes are on.
    private(set) var lastDisplayID: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let applyPair: (String) -> Void
    @ObservationIgnored private let applyScale: (Double) -> Void
    /// Puts a pair on screen without making it the main pair.
    @ObservationIgnored private let showPair: (String) -> Void
    /// The pair chosen for all displays.
    @ObservationIgnored private let mainPairID: () -> String?
    @ObservationIgnored private var displayTimer: Timer?

    init(settings: AppSettings,
         applyPair: @escaping (String) -> Void,
         applyScale: @escaping (Double) -> Void,
         showPair: @escaping (String) -> Void,
         mainPairID: @escaping () -> String?) {
        self.settings = settings
        self.applyPair = applyPair
        self.applyScale = applyScale
        self.showPair = showPair
        self.mainPairID = mainPairID
        followsAppearance = settings.followsAppearance
        lightPairID = settings.lightPairID
        darkPairID = settings.darkPairID
        perDisplaySizes = settings.perDisplaySizes
        perDisplayColors = settings.perDisplayColors
        displaySizes = settings.displaySizes
        displayPairs = settings.displayPairs
        perAppColors = settings.perAppColors
        appPairs = settings.appPairs
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        observeSystem()
        updateDisplayTracking()
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
        if perAppColors, let app = frontmostBundleID, let id = appPairs[app] { return id }
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

    private func frontmostAppChanged(_ app: NSRunningApplication?) {
        guard let id = app?.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return }
        frontmostBundleID = id
        if perAppColors { applyColors(for: lastDisplayID) }
    }

    private var tracksDisplays: Bool { perDisplaySizes || perDisplayColors }

    private func updateDisplayTracking() {
        displayTimer?.invalidate()
        displayTimer = nil
        lastDisplayID = nil
        guard tracksDisplays else { return }
        // Deferred: running it during init would call back into the model before it holds this object.
        DispatchQueue.main.async { [weak self] in self?.checkPointerDisplay() }
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPointerDisplay() }
        }
    }

    /// Applies the stored size and colors when the pointer crosses onto another display.
    private func checkPointerDisplay() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }),
              let display = DisplayInfo(screen: screen), display.id != lastDisplayID else { return }
        lastDisplayID = display.id
        if perDisplaySizes, let size = displaySizes[display.id] { applyScale(size) }
        applyColors(for: display.id)
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
            }
        }
    }
}
