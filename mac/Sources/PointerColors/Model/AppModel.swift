import AppKit
import Observation

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

    /// The factor for the app's own text and layout, resolved for the current main screen.
    var textScale: CGFloat {
        textSize.factor(screenWidth: NSScreen.main?.frame.width ?? 0)
    }

    var updateResult: UpdateChecker.Result?
    var isCheckingForUpdates = false
    var shortcuts: [ShortcutAction: KeyCombo] = [:]
    var shortcutConflicts: Set<ShortcutAction> = []

    let settings = AppSettings()
    let hotKeys = HotKeyCenter()
    private let pointer = SystemPointer()
    @ObservationIgnored private var automationStore: Automation?

    /// Appearance and per-display rules. Created on first use so it can call back into the model.
    var automation: Automation {
        if let automationStore { return automationStore }
        let created = Automation(settings: settings,
                                 applyPair: { [weak self] id in self?.applyPair(id: id) },
                                 applyScale: { [weak self] size in self?.setScale(size) },
                                 showPair: { [weak self] id in self?.showPair(id: id) },
                                 mainPairID: { [weak self] in self?.settings.lastAppliedPairID ?? self?.selectedID })
        automationStore = created
        return created
    }

    init() {
        selectedID = PointerPair.featured.id
        scale = SystemPointer.minimumScale
        iconInPairColors = settings.iconInPairColors
        textSize = settings.textSize
        shortcuts = settings.shortcuts
        refreshFromSystem()
        reapplyIfNeeded()
        registerShortcuts()
        automation.applyAppearancePair()
        Task { await checkForUpdatesIfDue() }
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
        if settings.perDisplayColors, let main = settings.lastAppliedPairID, library.pair(id: main) != nil {
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
        scale = value
        do {
            try pointer.setScale(value)
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
    }
}
