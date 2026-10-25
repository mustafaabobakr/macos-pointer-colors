import AppKit
import Observation
import SwiftUI

/// What the menu shows under the pair name.
enum ApplyStatus: Equatable {
    case applied
    case notApplied
    case copied(String)
    case failed(String)

    var message: String {
        switch self {
        case .applied: return String(localized: "Currently applied")
        case .notApplied: return String(localized: "Not applied yet")
        case .copied(let what): return String(localized: "\(what) copied")
        case .failed(let reason): return reason
        }
    }
}

@MainActor
@Observable
final class AppModel {
    private(set) var library = PairLibrary()
    private(set) var appliedPair: PointerPair?
    private(set) var status: ApplyStatus = .notApplied
    private(set) var needsFullDiskAccess = false
    private(set) var launchAtLogin = false
    var selectedID: String
    var scale: Double
    var iconInPairColors: Bool {
        didSet { settings.iconInPairColors = iconInPairColors }
    }
    var textSize: TextSize {
        didSet { settings.textSize = textSize }
    }
    var theme: AppTheme = .saved {
        didSet { theme.save(); theme.apply() }
    }
    var menuTint: MenuTint = .saved {
        didSet { menuTint.save() }
    }
    var menuGlass: MenuGlass = .saved {
        didSet { menuGlass.save() }
    }
    var menuTintStrength: Double = UserDefaults.standard.object(forKey: "menuTintStrength") as? Double ?? 0.35 {
        didSet { UserDefaults.standard.set(menuTintStrength, forKey: "menuTintStrength") }
    }

    var menuBackgroundStyle: MenuBackgroundStyle {
        MenuBackgroundStyle(glass: menuGlass, tint: menuTint.color(pointer: selectedPair), tintStrength: menuTintStrength)
    }
    /// Whether macOS itself is in dark mode, kept current for the System theme.
    var systemIsDark = AppTheme.systemIsDark

    /// Always a concrete scheme: SwiftUI keeps the last forced scheme when given nil, so
    /// System resolves to what macOS is showing right now.
    var colorScheme: ColorScheme { theme.colorScheme ?? (systemIsDark ? .dark : .light) }

    /// The factor for the app's own text and layout, resolved for the current main screen.
    var textScale: CGFloat {
        textSize.factor(screenWidth: NSScreen.main?.frame.width ?? 0)
    }

    var updateResult: UpdateChecker.Result?
    var isCheckingForUpdates = false
    var isInstallingUpdate = false
    /// Why the last in-place install failed, until the next check.
    var updateInstallError: String?
    /// The last check that reached GitHub, reused when the menu opens again soon after.
    @ObservationIgnored var lastUpdateCheck: (date: Date, result: UpdateChecker.Result)?
    var shortcuts: [ShortcutAction: KeyCombo] = [:]
    var shortcutConflicts: Set<ShortcutAction> = []

    let settings = AppSettings()
    let hotKeys = HotKeyCenter()
    let highlight = PointerHighlight()
    @ObservationIgnored private var highlightOverlay: HighlightOverlay?
    private let pointer = SystemPointer()
    @ObservationIgnored private var automationStore: Automation?
    /// A display's size waiting for its colors to be drawn.
    @ObservationIgnored private var pendingScale: RecolorWatch?

    /// Appearance and per-display rules. Created on first use so it can call back into the model.
    var automation: Automation {
        if let automationStore { return automationStore }
        let created = Automation(settings: settings,
                                 applyPair: { [weak self] id in self?.applyPair(id: id) },
                                 applyScale: { [weak self] size in self?.setScale(size) },
                                 showPair: { [weak self] id in self?.showPair(id: id) },
                                 showDisplay: { [weak self] id, size in self?.showDisplay(pairID: id, scale: size) },
                                 mainPairID: { [weak self] in self?.settings.lastAppliedPairID ?? self?.selectedID })
        automationStore = created
        return created
    }

    init() {
        selectedID = PointerPair.featured.id
        scale = SystemPointer.minimumScale
        iconInPairColors = settings.iconInPairColors
        textSize = settings.textSize
        DispatchQueue.main.async { [theme] in theme.apply() }
        observeSystemAppearance()
        shortcuts = settings.shortcuts
        refreshFromSystem()
        reapplyIfNeeded()
        registerShortcuts()
        automation.applyAppearancePair()
        highlightOverlay = HighlightOverlay(settings: highlight,
                                            pair: { [weak self] in self?.menuBarPair ?? .featured },
                                            pointerScale: { [weak self] in self?.scale ?? 1 })
        startUpdateSchedule()
    }

    var selectedPair: PointerPair { library.pair(id: selectedID) ?? PointerPair.featured }

    /// The icon follows what's on screen, falling back to the selection for unknown colors.
    var menuBarPair: PointerPair { appliedPair ?? selectedPair }

    // MARK: Reading the system

    func refreshFromSystem() {
        let colors = pointer.currentColors()
        appliedPair = library.pair(matching: colors.outline, fill: colors.fill)
        scale = pointer.currentScale()
        needsFullDiskAccess = !pointer.canWriteSettings()
        launchAtLogin = settings.launchAtLogin
        syncSelection()
        updateStatus()
    }

    /// The grid highlights the main pair. With per-display colors, what's on screen may be a
    /// display's own pair, so the saved main pair wins there.
    private func syncSelection() {
        if settings.perDisplayColors || settings.perAppColors, let main = settings.lastAppliedPairID, library.pair(id: main) != nil {
            selectedID = main
        } else if let appliedPair {
            selectedID = appliedPair.id
        }
    }

    // MARK: Actions

    func select(_ pair: PointerPair) {
        selectedID = pair.id
        updateStatus()
    }

    func applySelected() {
        apply(selectedPair)
    }

    /// Picking a pair in the menu applies it straight away.
    func choose(_ pair: PointerPair) {
        select(pair)
        applySelected()
        // A display with its own pair keeps it; the choice becomes the pair for every other one.
        automation.applyCurrentDisplayColors()
    }

    /// Puts a pair on screen for the current display only, keeping the main pair as it is.
    func showPair(id: String) {
        guard let pair = library.pair(id: id), pair != appliedPair else { return }
        do {
            try pointer.apply(pair)
            appliedPair = pair
            updateStatus()
        } catch {
            fail(error)
        }
    }

    /// Puts a display's pair and size on screen, skipping whatever is already showing.
    func showDisplay(pairID: String?, scale newScale: Double?) {
        pendingScale?.cancel()
        pendingScale = nil
        let pair = library.pair(id: pairID).flatMap { $0 == appliedPair ? nil : $0 }
        // Compared with the live size: a cancelled wait may already have changed it.
        let size = newScale.flatMap { abs($0 - pointer.currentScale()) < 0.001 ? nil : $0 }
        guard let pair else {
            if let size { setScale(size) }
            return
        }
        if let size { pendingScale = scaleAfterRecolor(size) }
        showPair(id: pair.id)
    }

    /// The size goes live the moment the new colors are drawn, then is saved like any other change.
    private func scaleAfterRecolor(_ size: Double) -> RecolorWatch {
        RecolorWatch(onRecolor: { _ = UniversalAccessCore.shared.setCursorScale(size) },
                     then: { [weak self] in self?.scaleIsLive(size) })
    }

    /// Applies a pair by id unless it's already on screen. Used by automation.
    func applyPair(id: String) {
        guard let pair = library.pair(id: id), pair != appliedPair else { return }
        selectedID = pair.id
        apply(pair)
    }

    /// Back to the macOS default pair for the current appearance, at normal size.
    func reset() {
        let systemDefault = PointerPair.systemDefault(dark: automation.isDarkMode)
        do {
            try pointer.apply(systemDefault)
            try pointer.setScale(SystemPointer.minimumScale)
            selectedID = systemDefault.id
            settings.lastAppliedPairID = nil
            settings.lastAppliedScale = nil
            automation.resetAllDisplaySizes()
            refreshFromSystem()
        } catch {
            fail(error)
        }
    }

    /// Changes the size live, as the slider moves.
    func setScale(_ value: Double) {
        updateScale(value) { try pointer.setScale($0) }
    }

    /// Records a size that RecolorWatch already put on screen, without applying it a second time.
    private func scaleIsLive(_ value: Double) {
        updateScale(value) { try pointer.saveScale($0) }
    }

    private func updateScale(_ value: Double, write: (Double) throws -> Void) {
        scale = value
        highlightOverlay?.refresh()
        do {
            try write(value)
            settings.lastAppliedScale = value
            automation.rememberSizeForCurrentDisplay(value)
        } catch {
            scale = pointer.currentScale()
            fail(error)
        }
    }

    /// Nil when this macOS doesn't expose the setting.
    var shakeToFind: Bool? { pointer.shakeToFindEnabled }

    func setShakeToFind(_ enabled: Bool) {
        do {
            try pointer.setShakeToFind(enabled)
        } catch {
            fail(error)
        }
    }

    /// Back to the macOS default size, leaving the colors alone.
    func resetScale() {
        setScale(SystemPointer.minimumScale)
    }

    var isDefaultScale: Bool { abs(scale - SystemPointer.minimumScale) < 0.01 }

    func copyHex(outline: Bool) {
        let hex = outline ? selectedPair.outline.hex : selectedPair.fill.hex
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(hex, forType: .string)
        status = .copied("\(outline ? String(localized: "Outline") : String(localized: "Fill")) \(hex)")
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Library

    func addCustom(name: String, outline: RGBA, fill: RGBA) {
        let pair = PointerPair.custom(name: name.isEmpty ? String(localized: "Custom") : name, outline: outline, fill: fill)
        library.add(pair)
        select(pair)
    }

    /// Adds a pair from a website link, reusing an existing pair with the same colors.
    func add(_ link: PairLink, apply shouldApply: Bool) {
        if let existing = library.pair(matching: link.outline, fill: link.fill) {
            select(existing)
        } else {
            addCustom(name: link.name, outline: link.outline, fill: link.fill)
        }
        if shouldApply { applySelected() }
    }

    func updateCustom(_ pair: PointerPair) {
        library.update(pair)
        updateStatus()
    }

    func removeCustom(_ pair: PointerPair) {
        library.remove(id: pair.id)
        if selectedID == pair.id { selectedID = PointerPair.featured.id }
        updateStatus()
    }

    func setHidden(_ hidden: Bool, pair: PointerPair) {
        library.setHidden(hidden, id: pair.id)
    }

    func importCustom(from data: Data) throws {
        try library.importCustom(from: data)
    }

    func exportCustom() throws -> Data {
        try library.exportCustom()
    }

    // MARK: Settings

    func exportAllSettings() throws -> Data {
        try SettingsBackup().export()
    }

    /// Restores every preference from a backup, then relaunches so each part reads it fresh.
    func importAllSettings(from data: Data) throws {
        try SettingsBackup().restore(from: data)
        try AppUpdater.relaunch()
        NSApp.terminate(nil)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try settings.setLaunchAtLogin(enabled)
        } catch {
            status = .failed(String(localized: "Couldn't change Launch at login: \(error.localizedDescription)"))
        }
        launchAtLogin = settings.launchAtLogin
    }

    // MARK: Private

    private func apply(_ pair: PointerPair) {
        do {
            try pointer.apply(pair)
            settings.lastAppliedPairID = pair.id
            if settings.playSoundOnApply { NSSound(named: "Pop")?.play() }
            refreshFromSystem()
        } catch {
            fail(error)
        }
    }

    private func reapplyIfNeeded() {
        guard settings.reapplyAtLaunch else { return }
        if let scale = settings.lastAppliedScale, abs(scale - self.scale) > 0.01 { setScale(scale) }
        guard let pair = library.pair(id: settings.lastAppliedPairID), pair != appliedPair else { return }
        apply(pair)
    }

    private func fail(_ error: Error) {
        if error as? SystemPointerError == .permissionDenied { needsFullDiskAccess = true }
        status = .failed(error.localizedDescription)
    }

    private func updateStatus() {
        status = appliedPair?.id == selectedID ? .applied : .notApplied
        highlightOverlay?.refresh()
    }
}

extension AppModel {
    /// Follows macOS light/dark changes so the System theme updates live.
    func observeSystemAppearance() {
        let name = Notification.Name("AppleInterfaceThemeChangedNotification")
        DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            // The new style is written just after the notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                MainActor.assumeIsolated { self?.systemIsDark = AppTheme.systemIsDark }
            }
        }
    }
}
