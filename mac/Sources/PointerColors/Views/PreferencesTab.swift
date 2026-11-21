import SwiftUI

/// A page of Preferences, listed in the sidebar under its group.
enum PreferencesTab: String, CaseIterable, Identifiable {
    case general, pairs, automation, appearance, ring, pulse, laser, press, speed, zoom, buttons, battery, shortcuts, about,
         whatsNew

    var id: Self { self }
    /// Still being tuned, so its sidebar row and page carry a BETA badge.
    var isBeta: Bool { self == .zoom }
    /// Names the page's screen in docs/features/features.json.
    var slug: String { rawValue }

    var title: LocalizedStringKey { details.title }

    /// The title as a string, for search.
    var name: String { details.name }

    var symbol: String { details.symbol }

    private typealias Details = (title: LocalizedStringKey, name: String, symbol: String)

    /// The page's title, searchable name and symbol, looked up within its sidebar group so each
    /// switch stays short.
    private var details: Details {
        switch PreferencesGroup.containing(self) {
        case .pointer: pointerDetails
        case .highlight: highlightDetails
        case .mouse: mouseDetails
        case .app: appDetails
        }
    }

    private var pointerDetails: Details {
        switch self {
        case .appearance:
            // The same symbol as Appearance in System Settings.
            ("Appearance", String(localized: "Appearance"), "circle.lefthalf.filled")
        case .pairs: ("Pairs", String(localized: "Pairs"), "cursorarrow")
        case .automation: ("Automation", String(localized: "Automation"), "wand.and.stars")
        default: ("General", String(localized: "General"), "gearshape")
        }
    }

    private var highlightDetails: Details {
        switch self {
        case .ring: ("Ring", String(localized: "Ring"), "circle.dashed")
        case .pulse: ("Pulse", String(localized: "Pulse"), "circle.circle")
        case .laser: ("Laser", String(localized: "Laser"), "scribble")
        default: ("Press", String(localized: "Press"), "arrow.down.right.and.arrow.up.left")
        }
    }

    private var mouseDetails: Details {
        switch self {
        case .zoom: ("Zoom", String(localized: "Zoom"), "plus.magnifyingglass")
        case .buttons: ("Buttons", String(localized: "Buttons"), "computermouse")
        case .battery: ("Battery", String(localized: "Battery"), "battery.75percent")
        default: ("Speed", String(localized: "Speed"), "hare")
        }
    }

    private var appDetails: Details {
        switch self {
        case .about: ("About", String(localized: "About"), "info.circle")
        case .whatsNew: ("What's New", String(localized: "What's New"), "sparkles")
        default: ("Shortcuts", String(localized: "Shortcuts"), "command")
        }
    }
}

/// The sidebar's headings, each with its pages in order.
enum PreferencesGroup: String, CaseIterable, Identifiable {
    case pointer, highlight, mouse, app

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .pointer: "Pointer"
        case .highlight: "Highlight"
        case .mouse: "Mouse"
        case .app: "App"
        }
    }

    var tabs: [PreferencesTab] {
        switch self {
        case .pointer: [.general, .pairs, .automation, .appearance]
        case .highlight: [.ring, .pulse, .laser, .press]
        case .mouse: [.speed, .zoom, .buttons, .battery]
        case .app: [.shortcuts, .about, .whatsNew]
        }
    }

    static func containing(_ tab: PreferencesTab) -> PreferencesGroup {
        allCases.first { $0.tabs.contains(tab) } ?? .pointer
    }
}
