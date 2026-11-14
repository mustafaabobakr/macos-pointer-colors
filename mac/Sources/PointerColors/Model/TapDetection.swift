/// Who decides that the Magic Mouse was double-tapped.
enum TapDetection: String, CaseIterable, Identifiable {
    /// macOS's own recognizer, the one Safari and Chrome zoom with. Needs Smart zoom on in
    /// System Settings › Mouse.
    case macOS
    /// Pointer Colors reads the touches itself, with the tap limits.
    case pointerColors
    /// Both must see the same double tap.
    case both

    var id: Self { self }

    var title: String {
        switch self {
        case .macOS: String(localized: "macOS only")
        case .pointerColors: String(localized: "Pointer Colors only")
        case .both: String(localized: "Both")
        }
    }

    /// Listens for macOS's double tap.
    var usesMacOS: Bool { self != .pointerColors }
    /// Reads the touches and applies the tap limits.
    var usesOwnTaps: Bool { self != .macOS }
}
