import Observation

/// Which Preferences page is showing, with the pages before and after it for Back and Forward,
/// and the card a search result asked for.
@MainActor
@Observable
final class PreferencesRouter {
    private(set) var tab: PreferencesTab
    /// The card to scroll to and outline, until the outline fades.
    private(set) var focus: String?
    /// Counts requests, so asking for the same card again still scrolls to it.
    private(set) var requestID = 0
    private var backStack: [PreferencesTab] = []
    private var forwardStack: [PreferencesTab] = []

    init(tab: PreferencesTab = .general) {
        self.tab = tab
    }

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    func show(_ tab: PreferencesTab, focus: String? = nil) {
        if tab != self.tab {
            backStack.append(self.tab)
            forwardStack.removeAll()
            self.tab = tab
        }
        self.focus = focus
        requestID += 1
    }

    func goBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(tab)
        move(to: previous)
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(tab)
        move(to: next)
    }

    func clearFocus(_ request: Int) {
        guard request == requestID else { return }
        focus = nil
    }

    private func move(to tab: PreferencesTab) {
        self.tab = tab
        focus = nil
        requestID += 1
    }
}
