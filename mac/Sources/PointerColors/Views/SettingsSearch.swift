import Foundation

/// One line in the sidebar's search results: a page, or a setting on it that opens the page at
/// its card.
struct SettingsSearchResult: Identifiable, Hashable {
    let tab: PreferencesTab
    /// The card the setting is in; nil for the page itself.
    let anchor: String?
    let title: String
    let symbol: String

    var id: String { "\(tab.rawValue)|\(anchor ?? "")|\(title)" }
    var isPage: Bool { anchor == nil }
}

/// Every setting search can find, by page and card.
@MainActor
enum SettingsSearch {
    /// Each page's matches, page first then its settings, in sidebar order. A page whose name
    /// matches lists all its settings.
    static func results(for query: String) -> [SettingsSearchResult] {
        let words = query.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }
        return PreferencesGroup.allCases.flatMap(\.tabs).flatMap { tab in
            results(on: tab, words: words)
        }
    }

    private static func results(on tab: PreferencesTab, words: [String]) -> [SettingsSearchResult] {
        let settings = items.filter { $0.tab == tab }
        let pageMatches = matches(tab.name, words)
        let found = pageMatches ? settings : settings.filter { matches($0.title, words) }
        guard pageMatches || !found.isEmpty else { return [] }
        return [SettingsSearchResult(tab: tab, anchor: nil, title: tab.name, symbol: tab.symbol)] + found
    }

    private static func matches(_ text: String, _ words: [String]) -> Bool {
        words.allSatisfy { text.localizedStandardContains($0) }
    }

    private static func item(_ tab: PreferencesTab, _ anchor: String, _ title: String, _ symbol: String) -> SettingsSearchResult {
        SettingsSearchResult(tab: tab, anchor: anchor, title: title, symbol: symbol)
    }

    static let items: [SettingsSearchResult] = [
        item(.general, "general.startup", String(localized: "Launch at login"), "power"),
        item(.general, "general.startup", String(localized: "Re-apply my pair when the app starts"), "arrow.clockwise"),
        item(.general, "general.startup", String(localized: "Draw the menu-bar icon in my colors"), "paintpalette"),
        item(.general, "general.startup", String(localized: "Play a sound when a pair is applied"), "speaker.wave.2"),
        item(.general, "general.menuBar", String(localized: "Show in menu bar"), "menubar.rectangle"),
        item(.general, "general.menuBar", String(localized: "Show in Dock"), "dock.rectangle"),
        item(.appearance, "appearance.theme", String(localized: "Theme"), "circle.lefthalf.filled"),
        item(.appearance, "appearance.menu", String(localized: "Menu glass"), "square.on.square"),
        item(.appearance, "appearance.menu", String(localized: "Menu tint"), "drop"),
        item(.appearance, "appearance.text", String(localized: "Text size"), "textformat.size"),
        item(.appearance, "appearance.icon", String(localized: "App icon"), "app.dashed"),
        item(.general, "general.backup", String(localized: "Back up all settings"), "externaldrive"),
        item(.general, "general.permission", String(localized: "Full Disk Access"), "lock.shield"),
        item(.general, "general.permission", String(localized: "Notifications"), "bell"),
        item(.general, "general.feedback", String(localized: "Send feedback"), "bubble.left.and.text.bubble.right"),
        item(.pairs, "pairs.list", String(localized: "Add custom pair"), "plus"),
        item(.pairs, "pairs.list", String(localized: "Hide pairs from the menu"), "eye.slash"),
        item(.automation, "automation.appearance", String(localized: "Switch pairs with light and dark appearance"), "circle.lefthalf.filled"),
        item(.automation, "automation.apps", String(localized: "Different pair for each app"), "square.grid.2x2"),
        item(.automation, "automation.finding", String(localized: "Shake mouse pointer to locate"), "arrow.left.and.right"),
        item(.automation, "automation.finding", String(localized: "Show pointer location"), "scope"),
        item(.automation, "automation.windows", String(localized: "Focus the window under the pointer"), "macwindow"),
        item(.highlight, "highlight.highlight", String(localized: "Ring around the pointer"), "circle.dashed"),
        item(.highlight, "highlight.pulse", String(localized: "Pulse"), "circle.circle"),
        item(.highlight, "highlight.laser", String(localized: "Laser"), "scribble"),
        item(.highlight, "highlight.press", String(localized: "Shrink the pointer on click"), "arrow.down.right.and.arrow.up.left"),
        item(.highlight, "highlight.pairColors", String(localized: "Colors for each pair"), "paintpalette"),
        item(.speed, "speed.mouse", String(localized: "Disable pointer acceleration"), "equal.circle"),
        item(.speed, "speed.mouse", String(localized: "Pointer acceleration"), "gauge.with.dots.needle.67percent"),
        item(.speed, "speed.mouse", String(localized: "Pointer speed"), "hare"),
        item(.buttons, "buttons.side", String(localized: "Back and forward in every app"), "arrow.left.arrow.right"),
        item(.buttons, "buttons.apps", String(localized: "Apps with their own back and forward keys"), "app.badge"),
        item(.buttons, "buttons.clicks", String(localized: "Fix accidental double-clicks"), "cursorarrow.click.2"),
        item(.battery, "battery.show", String(localized: "Next to the menu-bar icon"), "menubar.rectangle"),
        item(.battery, "battery.show", String(localized: "On the Dock icon"), "dock.rectangle"),
        item(.battery, "battery.low", String(localized: "Low battery"), "battery.25percent"),
        item(.shortcuts, "shortcuts.keys", String(localized: "Keyboard shortcuts"), "keyboard"),
        item(.about, "about.updates", String(localized: "Check for Updates…"), "arrow.down.circle"),
        item(.about, "about.updates", String(localized: "Install updates automatically"), "arrow.triangle.2.circlepath"),
        item(.about, "about.app", String(localized: "Star on GitHub"), "star"),
    ]
}
