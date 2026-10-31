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

/// How the pointer moves between its size and its pressed size.
enum PressCurve: String, CaseIterable, Identifiable {
    /// Fast at first, settling at the end.
    case easeOut
    /// Goes a little past the size, then settles back, like a spring.
    case bounce
    /// The same speed all the way.
    case linear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easeOut: return String(localized: "Ease out")
        case .bounce: return String(localized: "Bounce")
        case .linear: return String(localized: "Linear")
        }
    }

    /// How far along the change is, 0 to 1 (a bounce goes past 1), at `progress` 0 to 1 of the time.
    func value(at progress: Double) -> Double {
        let rest = progress - 1
        switch self {
        case .easeOut: return 1 + rest * rest * rest
        case .bounce: return 1 + 2.70158 * rest * rest * rest + 1.70158 * rest * rest
        case .linear: return progress
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
    /// The pointer shrinks a little while a button is down, like a pressed button. Works on its
    /// own, without the overlay.
    var shrinksOnPress: Bool { didSet { save(shrinksOnPress, Key.pressShrink) } }
    /// The pressed size, times the pointer's own size.
    var pressScale: Double { didSet { save(pressScale, Key.pressScale) } }
    /// Seconds the pointer takes to shrink when the button goes down.
    var pressDownDuration: Double { didSet { save(pressDownDuration, Key.pressDown) } }
    /// Seconds it takes to grow back when the button comes up.
    var pressUpDuration: Double { didSet { save(pressUpDuration, Key.pressUp) } }
    var pressCurve: PressCurve { didSet { save(pressCurve.rawValue, Key.pressCurve) } }
    var shrinksOnRightClick: Bool { didSet { save(shrinksOnRightClick, Key.pressRight) } }

    /// Off uses `pulseColor` instead of the pair's color.
    var pulseUsesPairColor: Bool { didSet { save(pulseUsesPairColor, Key.pulsePair) } }
    var pulseColor: RGBA { didSet { saveColor(pulseColor, Key.pulseColor) } }
    /// Draws each pulse line over a wider one in the pair's dark color, as the laser's outline.
    var pulseOutlined: Bool { didSet { save(pulseOutlined, Key.pulseOutline) } }
    /// Points of outline showing on each side of a pulse line.
    var pulseOutlineWidth: Double { didSet { save(pulseOutlineWidth, Key.pulseOutlineWidth) } }
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
    static let pulseOutlineWidthRange = 0.5...4.0
    static let trailFadeRange = 0.3...3.0
    static let pressScaleRange = 0.5...0.95
    static let pressDurationRange = 0.0...0.5

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.pulsePair: true, Key.pulseSize: 1.0, Key.pulseDuration: 0.45,
                                     Key.pulseRight: true, Key.laserPair: true, Key.laserSize: 1.0,
                                     Key.laserTrail: true, Key.laserFade: 0.9,
                                     Key.laserKeys: HoldKeys.option.rawValue, Key.pressShrink: false, Key.pressScale: 0.88,
                                     Key.pressDown: 0.08, Key.pressUp: 0.08, Key.pressRight: true])
        // Builds before the switches stored one choice: off, pulse or laser.
        let earlier = defaults.string(forKey: Key.oldMode)
        pulseOn = defaults.object(forKey: Key.pulseOn) as? Bool ?? (earlier == "pulse")
        laserOn = defaults.object(forKey: Key.laserOn) as? Bool ?? (earlier == "laser")
        showsRing = defaults.bool(forKey: Key.ring)
        shrinksOnPress = defaults.bool(forKey: Key.pressShrink)
        pressScale = defaults.double(forKey: Key.pressScale)
        pressDownDuration = defaults.double(forKey: Key.pressDown)
        pressUpDuration = defaults.double(forKey: Key.pressUp)
        pressCurve = defaults.string(forKey: Key.pressCurve).flatMap(PressCurve.init(rawValue:)) ?? .easeOut
        shrinksOnRightClick = defaults.bool(forKey: Key.pressRight)
        pulseUsesPairColor = defaults.bool(forKey: Key.pulsePair)
        pulseColor = Self.color(defaults, Key.pulseColor) ?? RGBA(hex: "FF9F0A")!
        pulseOutlined = defaults.object(forKey: Key.pulseOutline) as? Bool ?? true
        pulseOutlineWidth = defaults.object(forKey: Key.pulseOutlineWidth) as? Double ?? 1
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

    /// This press shrinks the pointer: shrinking is on, and it's a left click or right clicks count.
    func shrinks(isLeft: Bool) -> Bool {
        shrinksOnPress && (isLeft || shrinksOnRightClick)
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
        static let pressShrink = "highlightPressShrink"
        static let pressScale = "highlightPressScale"
        static let pressDown = "highlightPressDownDuration"
        static let pressUp = "highlightPressUpDuration"
        static let pressCurve = "highlightPressCurve"
        static let pressRight = "highlightPressRightClick"
        static let pulsePair = "highlightPulseUsesPair"
        static let pulseColor = "highlightPulseColor"
        static let pulseOutline = "highlightPulseOutline"
        static let pulseOutlineWidth = "highlightPulseOutlineWidth"
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
