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
        case .applied: return "Currently applied"
        case .notApplied: return "Not applied yet"
        case .copied(let what): return "\(what) copied"
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
                                 applyScale: { [weak self] size in self?.setScale(size) })
        automationStore = created
        return created
    }

    init() {
        selectedID = PointerPair.builtIns[0].id
        scale = SystemPointer.minimumScale
        iconInPairColors = settings.iconInPairColors
        textSize = settings.textSize
        shortcuts = settings.shortcuts
        refreshFromSystem()
        reapplyIfNeeded()
        registerShortcuts()
        automation.applyAppearancePair()
    }

    var selectedPair: PointerPair { library.pair(id: selectedID) ?? PointerPair.builtIns[0] }

    /// The icon follows what's on screen, falling back to the selection for unknown colors.
    var menuBarPair: PointerPair { appliedPair ?? selectedPair }

    // MARK: Reading the system

    func refreshFromSystem() {
        let colors = pointer.currentColors()
        appliedPair = library.pair(matching: colors.outline, fill: colors.fill)
        scale = pointer.currentScale()
        needsFullDiskAccess = !pointer.canWriteSettings()
        launchAtLogin = settings.launchAtLogin
        if let appliedPair { selectedID = appliedPair.id }
        updateStatus()
    }

    // MARK: Actions

    func select(_ pair: PointerPair) {
        selectedID = pair.id
        updateStatus()
    }

    func applySelected() {
        apply(selectedPair)
    }

    /// Applies a pair by id unless it's already on screen. Used by automation.
    func applyPair(id: String) {
        guard let pair = library.pair(id: id), pair != appliedPair else { return }
        selectedID = pair.id
        apply(pair)
    }

    func reset() {
        do {
            try pointer.resetColors()
            try pointer.setScale(SystemPointer.minimumScale)
            selectedID = PointerPair.classic.id
            settings.lastAppliedPairID = nil
            settings.lastAppliedScale = nil
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
        status = .copied("\(outline ? "Outline" : "Fill") \(hex)")
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    // MARK: Library

    func addCustom(name: String, outline: RGBA, fill: RGBA) {
        let pair = PointerPair.custom(name: name.isEmpty ? "Custom" : name, outline: outline, fill: fill)
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
        if selectedID == pair.id { selectedID = PointerPair.builtIns[0].id }
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
            status = .failed("Couldn't change Launch at login: \(error.localizedDescription)")
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
