import CoreGraphics

/// The sizes Preferences pages are built from, in points at text size 1×, and the narrowest the
/// page column and the window can get.
enum SettingsLayout {
    /// Around a page's column of cards.
    static let pagePadding: CGFloat = 22
    /// The widest a page's column of cards gets.
    static let pageMaxWidth: CGFloat = 760
    /// Inside a card, around its rows.
    static let cardPadding: CGFloat = 16
    /// A row's icon tile, and the gaps between its icon, title and control.
    static let iconSide: CGFloat = 26
    static let rowSpacing: CGFloat = 12
    /// The least a row's title gets: room for two words side by side, so it wraps only between words.
    static let titleMinWidth: CGFloat = 160
    /// The widest control a row has: Speed's slider, with its value field and reset button.
    static let widestControl: CGFloat = 360

    /// The page column never gets narrower than its cards at full width with their padding:
    /// 22 + 760 + 22 = 804. Cards never shrink, so no row ever squeezes its title or control.
    static let minPageWidth = pageMaxWidth + 2 * pagePadding
    /// The sidebar's usual width; the window's narrowest is it plus the narrowest page, 1034.
    static let sidebarWidth: CGFloat = 230
    static let minWindowWidth = sidebarWidth + minPageWidth
}
