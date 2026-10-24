import Foundation
import Observation

/// What happens on screen as you click and drag, for demos and recordings.
enum HighlightMode: String, CaseIterable, Identifiable {
    case off
    /// A ring that grows and fades where you click.
    case pulse
    /// A glowing dot that follows the pointer, and a fading trail while you drag.
    case laser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return String(localized: "Off")
        case .pulse: return String(localized: "Pulse")
        case .laser: return String(localized: "Laser")
        }
    }
}

/// The ring, pulse and laser settings, saved as they change. The overlay draws from them.
@MainActor
@Observable
final class PointerHighlight {
    var mode: HighlightMode { didSet { save(mode.rawValue, Key.mode) } }
    /// A ring that stays around the pointer, on its own or together with a mode.
    var showsRing: Bool { didSet { save(showsRing, Key.ring) } }

    /// Off uses `pulseColor` instead of the pair's outline.
    var pulseUsesPairColor: Bool { didSet { save(pulseUsesPairColor, Key.pulsePair) } }
    var pulseColor: RGBA { didSet { saveColor(pulseColor, Key.pulseColor) } }
    /// 0.5...2, times the pointer size.
    var pulseSize: Double { didSet { save(pulseSize, Key.pulseSize) } }
    /// Seconds from click to fully faded.
    var pulseDuration: Double { didSet { save(pulseDuration, Key.pulseDuration) } }
    var pulsesOnRightClick: Bool { didSet { save(pulsesOnRightClick, Key.pulseRight) } }

    /// Off uses `laserColor` instead of the pair's outline and fill.
    var laserUsesPairColor: Bool { didSet { save(laserUsesPairColor, Key.laserPair) } }
    var laserColor: RGBA { didSet { saveColor(laserColor, Key.laserColor) } }
    /// 0.5...2, times the default dot and trail width.
    var laserSize: Double { didSet { save(laserSize, Key.laserSize) } }
    /// Draws a trail while you drag.
    var laserTrail: Bool { didSet { save(laserTrail, Key.laserTrail) } }
    /// Seconds a finished trail takes to fade.
    var laserTrailFade: Double { didSet { save(laserTrailFade, Key.laserFade) } }

    static let sizeRange = 0.5...2.0
    static let pulseDurationRange = 0.2...1.5
    static let trailFadeRange = 0.3...3.0

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.pulsePair: true, Key.pulseSize: 1.0, Key.pulseDuration: 0.45,
                                     Key.pulseRight: true, Key.laserPair: true, Key.laserSize: 1.0,
                                     Key.laserTrail: true, Key.laserFade: 0.9])
        mode = defaults.string(forKey: Key.mode).flatMap(HighlightMode.init(rawValue:)) ?? .off
        showsRing = defaults.bool(forKey: Key.ring)
        pulseUsesPairColor = defaults.bool(forKey: Key.pulsePair)
        pulseColor = Self.color(defaults, Key.pulseColor) ?? RGBA(hex: "FF9F0A")!
        pulseSize = defaults.double(forKey: Key.pulseSize)
        pulseDuration = defaults.double(forKey: Key.pulseDuration)
        pulsesOnRightClick = defaults.bool(forKey: Key.pulseRight)
        laserUsesPairColor = defaults.bool(forKey: Key.laserPair)
        laserColor = Self.color(defaults, Key.laserColor) ?? RGBA(hex: "FF3B30")!
        laserSize = defaults.double(forKey: Key.laserSize)
        laserTrail = defaults.bool(forKey: Key.laserTrail)
        laserTrailFade = defaults.double(forKey: Key.laserFade)
    }

    /// True when anything needs the overlay.
    var isActive: Bool { showsRing || mode != .off }

    /// The pulse color: the pair's outline unless overridden.
    func pulseColor(for pair: PointerPair) -> RGBA {
        pulseUsesPairColor ? pair.outline : pulseColor
    }

    /// The laser's glow and core, middle and center colors. From the pair: outline, fill, white.
    /// Overridden: the custom color with a lighter middle.
    func laserColors(for pair: PointerPair) -> (glow: RGBA, middle: RGBA, center: RGBA) {
        let white = RGBA(red: 1, green: 1, blue: 1)
        guard !laserUsesPairColor else { return (pair.outline, pair.fill, white) }
        return (laserColor, laserColor.mixed(with: white, by: 0.45), white)
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    private func saveColor(_ color: RGBA, _ key: String) {
        defaults.set(try? JSONEncoder().encode(color), forKey: key)
    }

    private static func color(_ defaults: UserDefaults, _ key: String) -> RGBA? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(RGBA.self, from: $0) }
    }

    private enum Key {
        static let mode = "highlightMode"
        static let ring = "highlightRing"
        static let pulsePair = "highlightPulseUsesPair"
        static let pulseColor = "highlightPulseColor"
        static let pulseSize = "highlightPulseSize"
        static let pulseDuration = "highlightPulseDuration"
        static let pulseRight = "highlightPulseRightClick"
        static let laserPair = "highlightLaserUsesPair"
        static let laserColor = "highlightLaserColor"
        static let laserSize = "highlightLaserSize"
        static let laserTrail = "highlightLaserTrail"
        static let laserFade = "highlightLaserTrailFade"
    }
}

extension RGBA {
    /// Moves `fraction` of the way toward `other`.
    func mixed(with other: RGBA, by fraction: Double) -> RGBA {
        RGBA(red: red + (other.red - red) * fraction,
             green: green + (other.green - green) * fraction,
             blue: blue + (other.blue - blue) * fraction,
             alpha: alpha)
    }
}
