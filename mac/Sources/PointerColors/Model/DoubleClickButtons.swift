import CoreGraphics

/// The buttons the double-click fix watches.
enum DoubleClickButtons: String, CaseIterable, Identifiable {
    case left
    case leftAndRight

    var id: Self { self }

    /// The press and release events the fix needs to see.
    var eventTypes: [CGEventType] {
        switch self {
        case .left: [.leftMouseDown, .leftMouseUp]
        case .leftAndRight: [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
        }
    }

    var title: String {
        switch self {
        case .left: String(localized: "Left only")
        case .leftAndRight: String(localized: "Left and right")
        }
    }
}
