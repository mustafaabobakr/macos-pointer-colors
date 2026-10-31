import SwiftUI

/// A page of Preferences, listed in the sidebar under its group.
enum PreferencesTab: String, CaseIterable, Identifiable {
    case general, appearance, pairs, automation, highlight, speed, buttons, battery, shortcuts, about, whatsNew

    var id: Self { self }
    /// Names the page's screen in docs/features/features.json.
    var slug: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .appearance: "Appearance"
        case .pairs: "Pairs"
        case .automation: "Automation"
        case .highlight: "Highlight"
        case .speed: "Speed"
        case .buttons: "Buttons"
        case .battery: "Battery"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        case .whatsNew: "What's New"
        }
    }

    /// The title as a string, for search.
    var name: String {
        switch self {
        case .general: String(localized: "General")
        case .appearance: String(localized: "Appearance")
        case .pairs: String(localized: "Pairs")
        case .automation: String(localized: "Automation")
        case .highlight: String(localized: "Highlight")
        case .speed: String(localized: "Speed")
        case .buttons: String(localized: "Buttons")
        case .battery: String(localized: "Battery")
        case .shortcuts: String(localized: "Shortcuts")
        case .about: String(localized: "About")
        case .whatsNew: String(localized: "What's New")
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        // The same symbol as Appearance in System Settings.
        case .appearance: "circle.lefthalf.filled"
        case .pairs: "cursorarrow"
        case .automation: "wand.and.stars"
        case .highlight: "cursorarrow.rays"
        case .speed: "hare"
        case .buttons: "computermouse"
        case .battery: "battery.75percent"
        case .shortcuts: "command"
        case .about: "info.circle"
        case .whatsNew: "sparkles"
        }
    }
}

/// The sidebar's headings, each with its pages in order.
enum PreferencesGroup: String, CaseIterable, Identifiable {
    case pointer, mouse, app

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .pointer: "Pointer"
        case .mouse: "Mouse"
        case .app: "App"
        }
    }

    var tabs: [PreferencesTab] {
        switch self {
        case .pointer: [.general, .appearance, .pairs, .automation, .highlight]
        case .mouse: [.speed, .buttons, .battery]
        case .app: [.shortcuts, .about, .whatsNew]
        }
    }

    static func containing(_ tab: PreferencesTab) -> PreferencesGroup {
        allCases.first { $0.tabs.contains(tab) } ?? .pointer
    }
}
