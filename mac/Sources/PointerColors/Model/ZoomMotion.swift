/// What a whole-screen zoom does when the pointer moves.
enum ZoomMotion: String, CaseIterable, Identifiable {
    /// Like macOS Smart Zoom: the zoomed view stays put and the pointer works inside it.
    case stays
    /// The zoomed view moves with the pointer.
    case follows

    var id: Self { self }

    var title: String {
        switch self {
        case .stays: String(localized: "Stay where you zoomed")
        case .follows: String(localized: "Follow the pointer")
        }
    }
}
