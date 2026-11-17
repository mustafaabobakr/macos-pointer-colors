import CoreGraphics

/// The sizes Preferences pages are built from, in points at text size 1×, and the narrowest the
/// page column can get before a row would have to squeeze its title.
enum SettingsLayout {
    /// Around a page's column of cards.
    static let pagePadding: CGFloat = 22
    /// Inside a card, around its rows.
    static let cardPadding: CGFloat = 16
    /// A row's icon tile, and the gaps between its icon, title and control.
    static let iconSide: CGFloat = 26
    static let rowSpacing: CGFloat = 12
    /// The least a row's title gets: room for two words side by side, so it wraps only between words.
    static let titleMinWidth: CGFloat = 160
    /// The widest control a row has: Speed's slider, with its value field and reset button.
    static let widestControl: CGFloat = 360

    /// The narrowest page column that still fits the widest row with its title at full minimum:
    /// 22 + 16 + 26 + 12 + 160 + 12 + 360 + 16 + 22 = 646.
    static let minPageWidth = 2 * pagePadding + 2 * cardPadding + iconSide + rowSpacing + titleMinWidth
        + rowSpacing + widestControl
    /// The sidebar's usual width; the window's narrowest is it plus the narrowest page.
    static let sidebarWidth: CGFloat = 230
    static let minWindowWidth = sidebarWidth + minPageWidth
}
