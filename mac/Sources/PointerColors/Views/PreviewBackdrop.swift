import SwiftUI

/// The background the Preferences effect pictures are drawn on: dark, as before, or light, to see
/// how an effect reads over a light window. One choice for every picture, saved with the settings.
enum PreviewBackdrop: String, CaseIterable, Identifiable {
    case light
    case dark

    /// Where the choice is saved; Export all carries it with the rest of the domain.
    static let key = "previewBackdrop"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .light: Color(white: 0.93)
        case .dark: Color(white: 0.12)
        }
    }

    var symbol: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.fill"
        }
    }

    var label: Text {
        switch self {
        case .light: Text("Light background")
        case .dark: Text("Dark background")
        }
    }
}

private struct PreviewBackdropKey: EnvironmentKey {
    static let defaultValue = PreviewBackdrop.dark
}

extension EnvironmentValues {
    /// The background effect pictures draw on. Dark unless a Preferences page passes the saved choice.
    var previewBackdrop: PreviewBackdrop {
        get { self[PreviewBackdropKey.self] }
        set { self[PreviewBackdropKey.self] = newValue }
    }
}
