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

    let settings = AppSettings()
    private let pointer = SystemPointer()

    init() {
        selectedID = PointerPair.builtIns[0].id
        scale = SystemPointer.minimumScale
        iconInPairColors = settings.iconInPairColors
        refreshFromSystem()
        reapplyIfNeeded()
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
