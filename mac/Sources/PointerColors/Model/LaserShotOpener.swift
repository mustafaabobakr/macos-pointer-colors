import AppKit
import UniformTypeIdentifiers

/// Which app a laser screenshot opens in once it's taken, if any.
enum LaserShotOpener: String, CaseIterable, Identifiable {
    case none
    /// Whatever opens PNG files on this Mac, usually Preview.
    case defaultApp
    case shottr
    case cleanShot

    var id: Self { self }

    var title: String {
        switch self {
        case .none: String(localized: "Don't open")
        case .defaultApp: String(localized: "Default app")
        case .shottr: "Shottr"
        case .cleanShot: "CleanShot X"
        }
    }

    /// The app's bundle identifier, as its Info.plist names it; nil for the choices without one app.
    var bundleID: String? {
        switch self {
        case .none, .defaultApp: nil
        case .shottr: "cc.ffitch.shottr"
        case .cleanShot: "pl.maketheweb.cleanshotx"
        }
    }

    /// Where the app is installed; nil when it isn't, or for the choices without one app.
    var appURL: URL? {
        bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }

    /// The app that opens a screenshot: the chosen one, or the one that opens PNG files on this Mac.
    var resolvedAppURL: URL? {
        self == .defaultApp ? NSWorkspace.shared.urlForApplication(toOpen: .png) : appURL
    }

    /// The menu's name for the choice; the default app says which app that is, like "Default app (Preview)".
    var menuTitle: String {
        guard self == .defaultApp, let url = resolvedAppURL else { return title }
        return String(localized: "Default app (\(FileManager.default.displayName(atPath: url.path(percentEncoded: false))))")
    }

    /// The app's own icon, `size` points wide, for the menu; a "no" sign for Don't open.
    func menuIcon(size: Double) -> NSImage? {
        let image = resolvedAppURL.map { NSWorkspace.shared.icon(forFile: $0.path(percentEncoded: false)) }
            ?? NSImage(systemSymbolName: "nosign", accessibilityDescription: nil)
        guard let copy = image?.copy() as? NSImage else { return nil }
        copy.size = NSSize(width: size, height: size)
        return copy
    }

    /// Shown in the menu: always for the general choices, and for an app only when it's installed.
    var isAvailable: Bool { bundleID == nil || appURL != nil }

    /// Opens a screenshot. An app that isn't installed any more falls back to the default app.
    func open(_ file: URL) {
        guard self != .none else { return }
        guard let appURL else {
            NSWorkspace.shared.open(file)
            return
        }
        NSWorkspace.shared.open([file], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
