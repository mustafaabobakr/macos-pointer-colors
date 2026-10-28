import AppKit
import Observation

/// How a click pulse looks.
enum PulseStyle: String, CaseIterable, Identifiable {
    /// One ring that grows and fades.
    case ring
    /// Three thin rings, one after another, like a ripple on water.
    case ripple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ring: return String(localized: "Ring")
        case .ripple: return String(localized: "Ripple")
        }
    }
}

/// When the laser dot follows the pointer.
enum LaserDotMode: String, CaseIterable, Identifiable {
    /// On every pointer move.
    case always
    /// Only at the tip of a trail being drawn.
    case whileDrawing
    /// Never; a trail still draws.
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .always: return String(localized: "Always")
        case .whileDrawing: return String(localized: "While drawing")
        case .hidden: return String(localized: "Hide")
        }
    }
}

/// The color of the thin edge around the laser dot and along its trail.
enum LaserOutline: String, CaseIterable, Identifiable {
    /// The darker of the pair's outline and fill, so the laser stands out on light backgrounds.
    case dark
    /// The laser color itself.
    case laser
    /// No edge: the core's lighter shade goes right out to it.
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return String(localized: "Pair's dark color")
        case .laser: return String(localized: "Laser color")
        case .none: return String(localized: "None")
        }
    }
}

/// The two highlight effects. Each has its own switch, so either, both or neither can be on.
enum HighlightEffect: String, CaseIterable, Identifiable {
    /// A ring that grows and fades where you click.
    case pulse
    /// A glowing dot that follows the pointer, and a fading trail while you drag.
    case laser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: return String(localized: "Pulse")
        case .laser: return String(localized: "Laser")
        }
    }

    var systemImage: String {
        switch self {
        case .pulse: return "circle.dashed"
        case .laser: return "scribble"
        }
    }
}

/// The ring, pulse and laser settings, saved as they change. The overlay draws from them.
@MainActor
@Observable
final class PointerHighlight {
    var pulseOn: Bool { didSet { save(pulseOn, Key.pulseOn) } }
    var laserOn: Bool { didSet { save(laserOn, Key.laserOn) } }
    /// A ring that stays around the pointer, on its own or together with a mode.
    var showsRing: Bool { didSet { save(showsRing, Key.ring) } }

    /// Off uses `pulseColor` instead of the pair's color.
    var pulseUsesPairColor: Bool { didSet { save(pulseUsesPairColor, Key.pulsePair) } }
    var pulseColor: RGBA { didSet { saveColor(pulseColor, Key.pulseColor) } }
    /// 0.5...2, times the pointer size.
    var pulseSize: Double { didSet { save(pulseSize, Key.pulseSize) } }
    /// Seconds from click to fully faded.
    var pulseDuration: Double { didSet { save(pulseDuration, Key.pulseDuration) } }
    var pulsesOnRightClick: Bool { didSet { save(pulsesOnRightClick, Key.pulseRight) } }
    var pulseStyle: PulseStyle { didSet { save(pulseStyle.rawValue, Key.pulseStyle) } }
    /// A press held past a click keeps a filled ring under the pointer until release. Off by
    /// default: a long press then shows the same pulse as a click.
    var pulseShowsHold: Bool { didSet { save(pulseShowsHold, Key.pulseHold) } }

    /// Off uses `laserColor` instead of the pair's color.
    var laserUsesPairColor: Bool { didSet { save(laserUsesPairColor, Key.laserPair) } }
    var laserColor: RGBA { didSet { saveColor(laserColor, Key.laserColor) } }
    /// 0.5...2, times the default dot and trail width.
    var laserSize: Double { didSet { save(laserSize, Key.laserSize) } }
    /// Draws a trail while you drag.
    var laserTrail: Bool { didSet { save(laserTrail, Key.laserTrail) } }
    /// Seconds a finished trail takes to fade.
    var laserTrailFade: Double { didSet { save(laserTrailFade, Key.laserFade) } }
    /// Draws the laser only while `laserKeys` are held, catching the mouse so nothing underneath is
    /// clicked or selected. Off, the laser draws on any drag and the drag also reaches the app.
    var laserNeedsKeys: Bool { didSet { save(laserNeedsKeys, Key.laserOption) } }
    /// The keys `laserNeedsKeys` waits for; ⌥ Option unless changed.
    var laserKeys: HoldKeys { didSet { save(laserKeys.rawValue, Key.laserKeys) } }
    /// When the dot follows the pointer.
    var laserDot: LaserDotMode { didSet { save(laserDot.rawValue, Key.laserDot) } }
    /// The color of the edge around the dot and trail.
    var laserOutline: LaserOutline { didSet { save(laserOutline.rawValue, Key.laserOutline) } }

    /// Pulse and laser colors chosen for particular pairs, by pair id.
    private(set) var pairPulseColors: [String: RGBA] { didSet { saveColors(pairPulseColors, Key.pairPulse) } }
    private(set) var pairLaserColors: [String: RGBA] { didSet { saveColors(pairLaserColors, Key.pairLaser) } }

    static let sizeRange = 0.5...2.0
    static let pulseDurationRange = 0.2...1.5
    static let trailFadeRange = 0.3...3.0

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.pulsePair: true, Key.pulseSize: 1.0, Key.pulseDuration: 0.45,
                                     Key.pulseRight: true, Key.laserPair: true, Key.laserSize: 1.0,
                                     Key.laserTrail: true, Key.laserFade: 0.9,
                                     Key.laserKeys: HoldKeys.option.rawValue])
        // Builds before the switches stored one choice: off, pulse or laser.
        let earlier = defaults.string(forKey: Key.oldMode)
        pulseOn = defaults.object(forKey: Key.pulseOn) as? Bool ?? (earlier == "pulse")
        laserOn = defaults.object(forKey: Key.laserOn) as? Bool ?? (earlier == "laser")
        showsRing = defaults.bool(forKey: Key.ring)
        pulseUsesPairColor = defaults.bool(forKey: Key.pulsePair)
        pulseColor = Self.color(defaults, Key.pulseColor) ?? RGBA(hex: "FF9F0A")!
        pulseSize = defaults.double(forKey: Key.pulseSize)
        pulseDuration = defaults.double(forKey: Key.pulseDuration)
        pulsesOnRightClick = defaults.bool(forKey: Key.pulseRight)
        pulseStyle = defaults.string(forKey: Key.pulseStyle).flatMap(PulseStyle.init(rawValue:)) ?? .ring
        pulseShowsHold = defaults.bool(forKey: Key.pulseHold)
        laserUsesPairColor = defaults.bool(forKey: Key.laserPair)
        laserColor = Self.color(defaults, Key.laserColor) ?? RGBA(hex: "FF3B30")!
        laserSize = defaults.double(forKey: Key.laserSize)
        laserTrail = defaults.bool(forKey: Key.laserTrail)
        laserTrailFade = defaults.double(forKey: Key.laserFade)
        laserNeedsKeys = defaults.bool(forKey: Key.laserOption)
        let keys = HoldKeys(rawValue: defaults.integer(forKey: Key.laserKeys))
        laserKeys = keys.isEmpty ? .option : keys
        laserDot = defaults.string(forKey: Key.laserDot).flatMap(LaserDotMode.init(rawValue:)) ?? .always
        laserOutline = defaults.string(forKey: Key.laserOutline).flatMap(LaserOutline.init(rawValue:)) ?? .dark
        pairPulseColors = Self.colors(defaults, Key.pairPulse)
        pairLaserColors = Self.colors(defaults, Key.pairLaser)
    }

    /// True when anything needs the overlay.
    var isActive: Bool { showsRing || pulseOn || laserOn }

    func isOn(_ effect: HighlightEffect) -> Bool {
        effect == .pulse ? pulseOn : laserOn
    }

    func setOn(_ on: Bool, _ effect: HighlightEffect) {
        if effect == .pulse { pulseOn = on } else { laserOn = on }
    }

    /// This press sends out a pulse: pulses are on, and it's a left click or right clicks count.
    func pulses(isLeft: Bool) -> Bool {
        pulseOn && (isLeft || pulsesOnRightClick)
    }

    /// A drag draws a laser trail: the laser and its trail are on and, if it needs keys, they're held.
    func laserDraws(keysHeld: Bool) -> Bool {
        laserOn && laserTrail && (keysHeld || !laserNeedsKeys)
    }

    /// The laser's keys are all down in `flags`.
    func laserKeysHeld(in flags: NSEvent.ModifierFlags) -> Bool {
        laserKeys.areHeld(in: flags)
    }

    /// The laser dot shows for this move: always, or only while a trail is `drawing`.
    func laserDotShows(drawing: Bool) -> Bool {
        guard laserOn else { return false }
        switch laserDot {
        case .always: return true
        case .whileDrawing: return drawing
        case .hidden: return false
        }
    }

    /// The custom color when chosen; otherwise the color set for this pair, or the pair's own.
    func pulseColor(for pair: PointerPair) -> RGBA {
        pulseUsesPairColor ? pulsePairColor(pair) : pulseColor
    }

    /// The laser's glow, outline, middle and center: the laser color, the outline chosen in
    /// `laserOutline`, a lighter shade of the laser color, and white.
    func laserColors(for pair: PointerPair) -> LaserColors {
        let white = RGBA(red: 1, green: 1, blue: 1)
        let base = laserUsesPairColor ? laserPairColor(pair) : laserColor
        let middle = base.mixed(with: white, by: 0.45)
        let outlines: [LaserOutline: RGBA] = [.dark: pair.darkColor, .laser: base, .none: middle]
        return LaserColors(glow: base, outline: outlines[laserOutline] ?? base, middle: middle, center: white)
    }

    /// The pulse color for a pair, ignoring the custom color: set for it, or its own.
    func pulsePairColor(_ pair: PointerPair) -> RGBA { pairPulseColors[pair.id] ?? pair.highlightColor }

    func laserPairColor(_ pair: PointerPair) -> RGBA { pairLaserColors[pair.id] ?? pair.highlightColor }

    /// Nil goes back to the pair's own color.
    func setPulseColor(_ color: RGBA?, for pair: PointerPair) { pairPulseColors[pair.id] = color }

    func setLaserColor(_ color: RGBA?, for pair: PointerPair) { pairLaserColors[pair.id] = color }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    private func saveColor(_ color: RGBA, _ key: String) {
        defaults.set(try? JSONEncoder().encode(color), forKey: key)
    }

    private func saveColors(_ colors: [String: RGBA], _ key: String) {
        defaults.set(try? JSONEncoder().encode(colors), forKey: key)
    }

    private static func colors(_ defaults: UserDefaults, _ key: String) -> [String: RGBA] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: RGBA].self, from: $0) } ?? [:]
    }

    private static func color(_ defaults: UserDefaults, _ key: String) -> RGBA? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(RGBA.self, from: $0) }
    }

    private enum Key {
        static let oldMode = "highlightMode"
        static let laserOption = "highlightLaserNeedsOption"
        static let laserKeys = "highlightLaserKeys"
        static let laserDot = "highlightLaserDot"
        static let laserOutline = "highlightLaserOutline"
        static let pairPulse = "highlightPairPulseColors"
        static let pairLaser = "highlightPairLaserColors"
        static let pulseOn = "highlightPulse"
        static let laserOn = "highlightLaser"
        static let ring = "highlightRing"
        static let pulsePair = "highlightPulseUsesPair"
        static let pulseColor = "highlightPulseColor"
        static let pulseSize = "highlightPulseSize"
        static let pulseDuration = "highlightPulseDuration"
        static let pulseRight = "highlightPulseRightClick"
        static let pulseStyle = "highlightPulseStyle"
        static let pulseHold = "highlightPulseShowsHold"
        static let laserPair = "highlightLaserUsesPair"
        static let laserColor = "highlightLaserColor"
        static let laserSize = "highlightLaserSize"
        static let laserTrail = "highlightLaserTrail"
        static let laserFade = "highlightLaserTrailFade"
    }
}

extension PointerPair {
    /// The color highlights draw in: the more colorful of outline and fill, so a pair with a black
    /// outline, like Highlighter or Gold, doesn't pulse in black. When both are grey, the lighter.
    var highlightColor: RGBA {
        let (outlineChroma, fillChroma) = (outline.chroma, fill.chroma)
        if abs(outlineChroma - fillChroma) > 0.1 { return outlineChroma > fillChroma ? outline : fill }
        return outline.luminance >= fill.luminance ? outline : fill
    }

    /// The darker of outline and fill, like the black outline of Highlighter.
    var darkColor: RGBA { outline.luminance < fill.luminance ? outline : fill }
}

extension RGBA {
    /// How colorful: 0 for black, white and greys, up to 1 for pure colors.
    var chroma: Double { max(red, green, blue) - min(red, green, blue) }

    /// Perceived brightness, 0...1.
    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    /// Moves `fraction` of the way toward `other`.
    func mixed(with other: RGBA, by fraction: Double) -> RGBA {
        RGBA(red: red + (other.red - red) * fraction,
             green: green + (other.green - green) * fraction,
             blue: blue + (other.blue - blue) * fraction,
             alpha: alpha)
    }
}
