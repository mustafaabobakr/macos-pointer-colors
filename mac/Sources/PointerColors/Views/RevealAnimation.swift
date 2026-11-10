import AppKit
import SwiftUI

extension Animation {
    /// How Preferences moves when a card's content changes: rows opening or closing (see `Reveal`),
    /// rows added to or removed from a list, notices coming and going. A smooth spring, or none with
    /// Reduce Motion on, when changes simply appear.
    @MainActor static var reveal: Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : .smooth(duration: 0.35)
    }
}

extension Binding {
    /// A binding for a setting that shows or hides the rows that depend on it (see `Reveal`).
    /// Changes made through it animate with `Animation.reveal`: the card grows or shrinks and those
    /// rows fade with it.
    @MainActor
    func revealing() -> Binding<Value> {
        animation(.reveal)
    }
}
