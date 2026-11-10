import CoreGraphics
import Foundation

/// Which side of the pointer the battery label sits on. At a display's edge it moves to the
/// other side, so it always stays on screen.
enum BatteryLabelPosition: String, CaseIterable, Identifiable {
    case belowRight, belowLeft, aboveRight, aboveLeft

    var id: String { rawValue }

    var title: String {
        switch self {
        case .belowRight: String(localized: "Below right")
        case .belowLeft: String(localized: "Below left")
        case .aboveRight: String(localized: "Above right")
        case .aboveLeft: String(localized: "Above left")
        }
    }

    var isLeft: Bool { self == .belowLeft || self == .aboveLeft }
    var isAbove: Bool { self == .aboveRight || self == .aboveLeft }

    /// Points from the pointer's tip, clear of a large pointer below and to the right of it, and
    /// closer on the sides the pointer doesn't reach.
    static let below: CGFloat = 30
    static let side: CGFloat = 14

    /// The label's top-left corner from the pointer's tip, with y growing downward, as in SwiftUI.
    func offset(for size: CGSize) -> CGPoint {
        CGPoint(x: isLeft ? -Self.side - size.width : Self.side,
                y: isAbove ? -Self.side - size.height : Self.below)
    }

    /// The same side flipped left to right, or top to bottom, to stay on a display.
    func flipped(horizontally: Bool, vertically: Bool) -> BatteryLabelPosition {
        let left = isLeft != horizontally, above = isAbove != vertically
        return switch (left, above) {
        case (false, false): .belowRight
        case (true, false): .belowLeft
        case (false, true): .aboveRight
        case (true, true): .aboveLeft
        }
    }
}
