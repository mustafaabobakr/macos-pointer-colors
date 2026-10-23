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

extension View {
    /// Tinted Liquid Glass behind the menu on macOS 26 and later; a soft color wash before that.
    @ViewBuilder func menuTint(_ color: Color?) -> some View {
        if let color {
            if #available(macOS 26.0, *) {
                background(Color.clear.glassEffect(.regular.tint(color.opacity(0.35)), in: .rect(cornerRadius: 16)).padding(-6))
            } else {
                background(color.opacity(0.12))
            }
        } else {
            self
        }
    }
}
