import AppKit
import SwiftUI

/// The app's own light/dark look. System follows macOS.
enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    private var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    /// For SwiftUI windows the AppKit appearance doesn't reach, like the menu-bar panel.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    @MainActor func apply() {
        NSApp.appearance = appearance
    }

    static var saved: AppTheme {
        UserDefaults.standard.string(forKey: "appTheme").flatMap(AppTheme.init(rawValue:)) ?? .system
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "appTheme")
    }
}
