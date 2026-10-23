import SwiftUI

/// A tint for the menu's glass background.
enum MenuTint: String, CaseIterable, Identifiable {
    case none, pointer, blue, purple, pink, orange, green, graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return String(localized: "None")
        case .pointer: return String(localized: "Pointer color")
        case .blue: return String(localized: "Blue")
        case .purple: return String(localized: "Purple")
        case .pink: return String(localized: "Pink")
        case .orange: return String(localized: "Orange")
        case .green: return String(localized: "Green")
        case .graphite: return String(localized: "Graphite")
        }
    }

    private static let fixed: [MenuTint: Color] = [
        .blue: .blue, .purple: .purple, .pink: .pink, .orange: .orange, .green: .green, .graphite: .gray,
    ]

    /// Nil means untinted. "Pointer color" follows the selected pair's fill.
    func color(pointer pair: PointerPair) -> Color? {
        self == .pointer ? pair.fill.color : Self.fixed[self]
    }

    static var saved: MenuTint {
        UserDefaults.standard.string(forKey: "menuTint").flatMap(MenuTint.init(rawValue:)) ?? .none
    }

    func save() { UserDefaults.standard.set(rawValue, forKey: "menuTint") }
}

/// How the menu's glass background looks.
enum MenuGlass: String, CaseIterable, Identifiable {
    case system, regular, clear, off

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "Standard")
        case .regular: return String(localized: "Frosted")
        case .clear: return String(localized: "Clear")
        case .off: return String(localized: "Off")
        }
    }

    static var saved: MenuGlass {
        UserDefaults.standard.string(forKey: "menuGlass").flatMap(MenuGlass.init(rawValue:)) ?? .system
    }

    func save() { UserDefaults.standard.set(rawValue, forKey: "menuGlass") }
}

/// Everything that styles the menu background.
struct MenuBackgroundStyle {
    var glass: MenuGlass
    var tint: Color?
    /// 0...1; how much of the tint shows through.
    var tintStrength: Double
}

extension View {
    /// Liquid Glass behind the menu on macOS 26 and later; a soft color wash before that.
    @ViewBuilder func menuBackground(_ style: MenuBackgroundStyle) -> some View {
        if style.glass == .off {
            // No glass: a solid window background, with the tint as a flat wash.
            background(Color(nsColor: .windowBackgroundColor).overlay(style.tint?.opacity(style.tintStrength * 0.35)).padding(-6))
        } else if #available(macOS 26.0, *), let glass = style.glassEffect {
            background(Color.clear.glassEffect(glass, in: .rect(cornerRadius: 16)).padding(-6))
        } else if let tint = style.tint {
            background(tint.opacity(style.tintStrength * 0.35))
        } else {
            self
        }
    }
}

extension MenuBackgroundStyle {
    /// Nil keeps the menu's standard background.
    @available(macOS 26.0, *)
    var glassEffect: Glass? {
        let base: Glass
        switch glass {
        case .system:
            guard tint != nil else { return nil }
            base = .regular
        case .regular: base = .regular
        case .clear: base = .clear
        case .off: return nil
        }
        guard let tint else { return base }
        return base.tint(tint.opacity(tintStrength))
    }
}
