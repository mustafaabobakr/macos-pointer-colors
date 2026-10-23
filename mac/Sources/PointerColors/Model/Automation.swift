import AppKit
import Observation

/// A connected display, identified by a UUID that survives reboots and replugging.
struct DisplayInfo: Identifiable, Equatable {
    let id: String
    let name: String

    static func current() -> [DisplayInfo] {
        NSScreen.screens.compactMap(DisplayInfo.init(screen:))
    }

    init?(screen: NSScreen) {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) as String? else { return nil }
        id = string
        name = screen.localizedName
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
    private(set) var displaySizes: [String: Double]
    private(set) var displays: [DisplayInfo] = DisplayInfo.current()
    /// The display the pointer is on, while per-display sizes are on.
    private(set) var lastDisplayID: String?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let applyPair: (String) -> Void
    @ObservationIgnored private let applyScale: (Double) -> Void
    @ObservationIgnored private var displayTimer: Timer?

    init(settings: AppSettings, applyPair: @escaping (String) -> Void, applyScale: @escaping (Double) -> Void) {
        self.settings = settings
        self.applyPair = applyPair
        self.applyScale = applyScale
        followsAppearance = settings.followsAppearance
        lightPairID = settings.lightPairID
        darkPairID = settings.darkPairID
        perDisplaySizes = settings.perDisplaySizes
        displaySizes = settings.displaySizes
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

    private func updateDisplayTracking() {
        displayTimer?.invalidate()
        displayTimer = nil
        lastDisplayID = nil
        guard perDisplaySizes else { return }
        checkPointerDisplay()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPointerDisplay() }
        }
    }

    /// Applies the stored size when the pointer crosses onto another display.
    private func checkPointerDisplay() {
        let location = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(location, $0.frame, false) }),
              let display = DisplayInfo(screen: screen), display.id != lastDisplayID else { return }
        lastDisplayID = display.id
        if let size = displaySizes[display.id] { applyScale(size) }
    }

    // MARK: System notifications

    private func observeSystem() {
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
