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

/// How the laser dot and trail are drawn.
enum LaserLook: String, CaseIterable, Identifiable {
    /// A white center in a lighter shade of the laser color, with an outline and a faint glow.
    case classic
    /// A white core in a soft, bright glow of the laser color, with no outline, as GoodNotes draws its laser.
    case goodNotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return String(localized: "Classic")
        case .goodNotes: return String(localized: "GoodNotes")
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
    /// The pointer itself shrinks while a button is down.
    case press

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: return String(localized: "Pulse")
        case .laser: return String(localized: "Laser")
        case .press: return String(localized: "Press")
        }
    }

    var systemImage: String {
        switch self {
        case .pulse: return "circle.dashed"
        case .laser: return "scribble"
        case .press: return "arrow.down.right.and.arrow.up.left"
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
    /// 0.1...2, times the ring's default size, which follows the pointer size.
    var ringSize: Double { didSet { save(ringSize, Key.ringSize) } }
    /// Off uses `ringColor` instead of the pair's color.
    var ringUsesPairColor: Bool { didSet { save(ringUsesPairColor, Key.ringPair) } }
    var ringColor: RGBA { didSet { saveColor(ringColor, Key.ringColor) } }
    /// How tinted the inside of the ring is, 0 for clear.
    var ringFill: Double { didSet { save(ringFill, Key.ringFill) } }
    /// Points wide, the ring's edge.
    var ringLineWidth: Double { didSet { save(ringLineWidth, Key.ringLineWidth) } }
    /// How solid the ring's edge is.
    var ringOpacity: Double { didSet { save(ringOpacity, Key.ringOpacity) } }
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

    /// The Ring style: points wide, how far it grows (times its base size), and how solid it starts.
    var pulseLineWidth: Double { didSet { save(pulseLineWidth, Key.pulseLineWidth) } }
    var pulseGrowth: Double { didSet { save(pulseGrowth, Key.pulseGrowth) } }
    var pulseOpacity: Double { didSet { save(pulseOpacity, Key.pulseOpacity) } }
    /// The Ripple style: how many waves, how far each grows, the gap between them as a share of
    /// the pulse length, each wave's starting width in points, and how solid it starts.
    var rippleWaves: Int { didSet { save(rippleWaves, Key.rippleWaves) } }
    var rippleGrowth: Double { didSet { save(rippleGrowth, Key.rippleGrowth) } }
    var rippleSpacing: Double { didSet { save(rippleSpacing, Key.rippleSpacing) } }
    var rippleLineWidth: Double { didSet { save(rippleLineWidth, Key.rippleLineWidth) } }
    var rippleOpacity: Double { didSet { save(rippleOpacity, Key.rippleOpacity) } }
    /// The long-press ring: seconds held before it shows, its size against the pulse's base
    /// size, how tinted its inside is, its edge in points, and whether it breathes while held.
    var holdDelay: Double { didSet { save(holdDelay, Key.holdDelay) } }
    var holdSize: Double { didSet { save(holdSize, Key.holdSize) } }
    var holdFill: Double { didSet { save(holdFill, Key.holdFill) } }
    var holdLineWidth: Double { didSet { save(holdLineWidth, Key.holdLineWidth) } }
    var holdBreathes: Bool { didSet { save(holdBreathes, Key.holdBreathes) } }

    /// Off uses `laserColor` instead of the pair's color.
    var laserUsesPairColor: Bool { didSet { save(laserUsesPairColor, Key.laserPair) } }
    var laserColor: RGBA { didSet { saveColor(laserColor, Key.laserColor) } }
    /// 0.5...2, times the default dot and trail width.
    var laserSize: Double { didSet { save(laserSize, Key.laserSize) } }
    /// Draws a trail while you drag.
    var laserTrail: Bool { didSet { save(laserTrail, Key.laserTrail) } }
    /// Seconds a finished trail takes to fade.
    var laserTrailFade: Double { didSet { save(laserTrailFade, Key.laserFade) } }
    /// Draws the laser only while `laserKeys` are held. Off, the laser draws on any drag.
    var laserNeedsKeys: Bool { didSet { save(laserNeedsKeys, Key.laserOption) } }
    /// While `laserNeedsKeys` and its keys are held, the drag draws without clicking or selecting
    /// anything underneath. On by default; off, the drag also reaches the app.
    var laserBlocksClicks: Bool { didSet { save(laserBlocksClicks, Key.laserBlocksClicks) } }
    /// The keys `laserNeedsKeys` waits for; ⌥ Option unless changed.
    var laserKeys: HoldKeys { didSet { save(laserKeys.rawValue, Key.laserKeys) } }
    /// When the dot follows the pointer.
    var laserDot: LaserDotMode { didSet { save(laserDot.rawValue, Key.laserDot) } }
    /// The color of the edge around the dot and trail.
    var laserOutline: LaserOutline { didSet { save(laserOutline.rawValue, Key.laserOutline) } }
    /// 0.05...1: how solid that edge is, 1 unless changed.
    var laserOutlineOpacity: Double { didSet { save(laserOutlineOpacity, Key.laserOutlineOpacity) } }
    /// Classic unless changed.
    var laserLook: LaserLook { didSet { save(laserLook.rawValue, Key.laserLook) } }
    /// Seconds the dot takes to fade once the pointer stops.
    var laserDotFade: Double { didSet { save(laserDotFade, Key.laserDotFade) } }
    /// Classic: how solid the trail is while drawn, how strong its glow is (the dot's is 90% of
    /// it), and how far the middle line is lightened toward white.
    var laserTrailOpacity: Double { didSet { save(laserTrailOpacity, Key.laserTrailOpacity) } }
    var laserGlow: Double { didSet { save(laserGlow, Key.laserGlow) } }
    var laserCoreLightness: Double { didSet { save(laserCoreLightness, Key.laserCoreLightness) } }
    /// GoodNotes: seconds a finished trail takes to fade after it's held whole, and points the
    /// edge adds around the line and dot.
    var laserFadeOut: Double { didSet { save(laserFadeOut, Key.laserFadeOut) } }
    var laserRim: Double { didSet { save(laserRim, Key.laserRim) } }
    /// Takes a screenshot of the area around each finished trail.
    var laserShotOn: Bool { didSet { save(laserShotOn, Key.laserShotOn) } }
    /// Points of screen kept around the trail on every side.
    var laserShotMargin: Double { didSet { save(laserShotMargin, Key.laserShotMargin) } }
    /// Keeps the drawn trail in the screenshot; off captures the screen under it.
    var laserShotIncludesTrail: Bool { didSet { save(laserShotIncludesTrail, Key.laserShotTrail) } }
    var laserShotCopies: Bool { didSet { save(laserShotCopies, Key.laserShotCopies) } }
    /// While a Magic Mouse zoom is up, captures everything it shows, without the margin. On unless changed.
    var laserShotWholeZoom: Bool { didSet { save(laserShotWholeZoom, Key.laserShotWholeZoom) } }
    /// Which Magic Mouse zooms end once the screenshot is taken. Both unless changed.
    var laserShotZoomOut: LaserShotZoomOut { didSet { save(laserShotZoomOut.rawValue, Key.laserShotZoomOut) } }
    /// Saves each screenshot in `laserShotFolder`.
    var laserShotSaves: Bool { didSet { save(laserShotSaves, Key.laserShotSaves) } }
    /// A folder path; the Desktop unless changed.
    var laserShotFolder: String { didSet { save(laserShotFolder, Key.laserShotFolder) } }
    var laserShotOpener: LaserShotOpener { didSet { save(laserShotOpener.rawValue, Key.laserShotOpener) } }

    static let sizeRange = 0.5...2.0
    /// The ring can shrink to a tenth, tight around the pointer's tip.
    static let ringSizeRange = 0.1...2.0
    static let pulseDurationRange = 0.2...1.5
    static let pulseOutlineWidthRange = 0.5...4.0
    static let trailFadeRange = 0.3...3.0
    static let outlineOpacityRange = 0.05...1.0
    static let pressScaleRange = 0.5...0.95
    static let pressDurationRange = 0.0...0.5
    static let fillRange = 0.0...0.5
    static let lineWidthRange = 1.0...8.0
    static let opacityRange = 0.3...1.0
    static let growthRange = 1.2...3.0
    static let rippleWavesRange = 2...5
    /// At most 20%, so even five waves leave each one a fifth of the pulse length to grow.
    static let rippleSpacingRange = 0.05...0.2
    static let rippleLineWidthRange = 1.0...6.0
    static let holdDelayRange = 0.2...1.5
    static let holdSizeRange = 0.3...1.2
    static let holdFillRange = 0.0...0.8
    static let holdLineWidthRange = 1.0...6.0
    static let dotFadeRange = 0.2...3.0
    static let trailOpacityRange = 0.4...1.0
    static let glowRange = 0.0...0.6
    static let coreLightnessRange = 0.0...0.8
    static let fadeOutRange = 0.1...1.0
    static let rimRange = 1.0...6.0
    static let shotMarginRange = 0.0...400.0

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.pulsePair: true, Key.pulseSize: 1.0, Key.ringSize: 1.0, Key.pulseDuration: 0.45,
                                     Key.pulseRight: true, Key.laserPair: true, Key.laserSize: 1.0,
                                     Key.laserTrail: true, Key.laserFade: 0.9, Key.laserOutlineOpacity: 1.0,
                                     Key.laserKeys: HoldKeys.option.rawValue, Key.laserBlocksClicks: true, Key.pressShrink: false, Key.pressScale: 0.88,
                                     Key.pressDown: 0.08, Key.pressUp: 0.08, Key.pressRight: true])
        defaults.register(defaults: Self.lookDefaults)
        // Builds before the switches stored one choice: off, pulse or laser.
        let earlier = defaults.string(forKey: Key.oldMode)
        pulseOn = defaults.object(forKey: Key.pulseOn) as? Bool ?? (earlier == "pulse")
        laserOn = defaults.object(forKey: Key.laserOn) as? Bool ?? (earlier == "laser")
        showsRing = defaults.bool(forKey: Key.ring)
        ringSize = defaults.double(forKey: Key.ringSize)
        ringUsesPairColor = defaults.bool(forKey: Key.ringPair)
        ringColor = Self.color(defaults, Key.ringColor) ?? RGBA(red: 1, green: 1, blue: 1)
        ringFill = defaults.double(forKey: Key.ringFill)
        ringLineWidth = defaults.double(forKey: Key.ringLineWidth)
        ringOpacity = defaults.double(forKey: Key.ringOpacity)
        pulseLineWidth = defaults.double(forKey: Key.pulseLineWidth)
        pulseGrowth = defaults.double(forKey: Key.pulseGrowth)
        pulseOpacity = defaults.double(forKey: Key.pulseOpacity)
        rippleWaves = defaults.integer(forKey: Key.rippleWaves)
        rippleGrowth = defaults.double(forKey: Key.rippleGrowth)
        rippleSpacing = defaults.double(forKey: Key.rippleSpacing)
        rippleLineWidth = defaults.double(forKey: Key.rippleLineWidth)
        rippleOpacity = defaults.double(forKey: Key.rippleOpacity)
        holdDelay = defaults.double(forKey: Key.holdDelay)
        holdSize = defaults.double(forKey: Key.holdSize)
        holdFill = defaults.double(forKey: Key.holdFill)
        holdLineWidth = defaults.double(forKey: Key.holdLineWidth)
        holdBreathes = defaults.bool(forKey: Key.holdBreathes)
        laserDotFade = defaults.double(forKey: Key.laserDotFade)
        laserTrailOpacity = defaults.double(forKey: Key.laserTrailOpacity)
        laserGlow = defaults.double(forKey: Key.laserGlow)
        laserCoreLightness = defaults.double(forKey: Key.laserCoreLightness)
        laserFadeOut = defaults.double(forKey: Key.laserFadeOut)
        laserRim = defaults.double(forKey: Key.laserRim)
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
        laserBlocksClicks = defaults.bool(forKey: Key.laserBlocksClicks)
        let keys = HoldKeys(rawValue: defaults.integer(forKey: Key.laserKeys))
        laserKeys = keys.isEmpty ? .option : keys
        laserDot = defaults.string(forKey: Key.laserDot).flatMap(LaserDotMode.init(rawValue:)) ?? .always
        laserOutline = defaults.string(forKey: Key.laserOutline).flatMap(LaserOutline.init(rawValue:)) ?? .dark
        laserOutlineOpacity = defaults.double(forKey: Key.laserOutlineOpacity)
        laserLook = defaults.string(forKey: Key.laserLook).flatMap(LaserLook.init(rawValue:)) ?? .classic
        laserShotOn = defaults.bool(forKey: Key.laserShotOn)
        laserShotMargin = defaults.double(forKey: Key.laserShotMargin)
        laserShotIncludesTrail = defaults.bool(forKey: Key.laserShotTrail)
        laserShotCopies = defaults.bool(forKey: Key.laserShotCopies)
        laserShotWholeZoom = defaults.bool(forKey: Key.laserShotWholeZoom)
        laserShotZoomOut = defaults.string(forKey: Key.laserShotZoomOut).flatMap(LaserShotZoomOut.init) ?? .both
        laserShotSaves = defaults.bool(forKey: Key.laserShotSaves)
        laserShotFolder = defaults.string(forKey: Key.laserShotFolder) ?? Self.desktopPath
        laserShotOpener = defaults.string(forKey: Key.laserShotOpener).flatMap(LaserShotOpener.init(rawValue:)) ?? .none
    }

    private static var desktopPath: String {
        (FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? URL(filePath: NSHomeDirectory()).appending(path: "Desktop")).path(percentEncoded: false)
    }

    /// The looks' starting values: what each one drew before it could be changed.
    private static let lookDefaults: [String: Any] = [
        Key.ringPair: true, Key.ringFill: 0.18, Key.ringLineWidth: 3.0, Key.ringOpacity: 0.9,
        Key.pulseLineWidth: 4.0, Key.pulseGrowth: 1.8, Key.pulseOpacity: 0.95,
        Key.rippleWaves: 3, Key.rippleGrowth: 2.2, Key.rippleSpacing: 0.15, Key.rippleLineWidth: 3.0, Key.rippleOpacity: 0.9,
        Key.holdDelay: 0.35, Key.holdSize: 0.55, Key.holdFill: 0.35, Key.holdLineWidth: 3.0, Key.holdBreathes: true,
        Key.laserDotFade: 0.42, Key.laserTrailOpacity: 0.95, Key.laserGlow: 0.2, Key.laserCoreLightness: 0.45,
        Key.laserFadeOut: 0.35, Key.laserRim: 2.4,
        Key.laserShotMargin: 20.0, Key.laserShotTrail: true, Key.laserShotCopies: true, Key.laserShotSaves: true,
        Key.laserShotWholeZoom: true,
    ]

    /// True when anything needs the overlay.
    var isActive: Bool { showsRing || pulseOn || laserOn }

    func isOn(_ effect: HighlightEffect) -> Bool {
        switch effect {
        case .pulse: return pulseOn
        case .laser: return laserOn
        case .press: return shrinksOnPress
        }
    }

    func setOn(_ on: Bool, _ effect: HighlightEffect) {
        switch effect {
        case .pulse: pulseOn = on
        case .laser: laserOn = on
        case .press: shrinksOnPress = on
        }
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
        pulseUsesPairColor ? pair.highlightColor : pulseColor
    }

    /// The laser's glow, outline, middle and center: the laser color, the outline chosen in
    /// `laserOutline`, a lighter shade of the laser color, and white.
    func laserColors(for pair: PointerPair) -> LaserColors {
        let white = RGBA(red: 1, green: 1, blue: 1)
        let base = laserUsesPairColor ? pair.highlightColor : laserColor
        let middle = base.mixed(with: white, by: laserCoreLightness)
        let outlines: [LaserOutline: RGBA] = [.dark: pair.darkColor, .laser: base, .none: middle]
        return LaserColors(glow: base, outline: outlines[laserOutline] ?? base, middle: middle, center: white)
    }

    func ringColor(for pair: PointerPair) -> RGBA {
        ringUsesPairColor ? pair.highlightColor : ringColor
    }

    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }

    private func saveColor(_ color: RGBA, _ key: String) {
        defaults.set(try? JSONEncoder().encode(color), forKey: key)
    }

    private static func color(_ defaults: UserDefaults, _ key: String) -> RGBA? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(RGBA.self, from: $0) }
    }

    private enum Key {
        static let oldMode = "highlightMode"
        static let laserOption = "highlightLaserNeedsOption"
        static let laserKeys = "highlightLaserKeys"
        static let laserBlocksClicks = "highlightLaserBlocksClicks"
        static let laserDot = "highlightLaserDot"
        static let laserOutline = "highlightLaserOutline"
        static let laserOutlineOpacity = "highlightLaserOutlineOpacity"
        static let laserLook = "highlightLaserLook"
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
        static let ringSize = "highlightRingSize"
        static let laserTrail = "highlightLaserTrail"
        static let laserFade = "highlightLaserTrailFade"
        static let ringPair = "highlightRingUsesPair"
        static let ringColor = "highlightRingColor"
        static let ringFill = "highlightRingFill"
        static let ringLineWidth = "highlightRingLineWidth"
        static let ringOpacity = "highlightRingOpacity"
        static let pulseLineWidth = "highlightPulseLineWidth"
        static let pulseGrowth = "highlightPulseGrowth"
        static let pulseOpacity = "highlightPulseOpacity"
        static let rippleWaves = "highlightRippleWaves"
        static let rippleGrowth = "highlightRippleGrowth"
        static let rippleSpacing = "highlightRippleSpacing"
        static let rippleLineWidth = "highlightRippleLineWidth"
        static let rippleOpacity = "highlightRippleOpacity"
        static let holdDelay = "highlightHoldDelay"
        static let holdSize = "highlightHoldSize"
        static let holdFill = "highlightHoldFill"
        static let holdLineWidth = "highlightHoldLineWidth"
        static let holdBreathes = "highlightHoldBreathes"
        static let laserDotFade = "highlightLaserDotFade"
        static let laserTrailOpacity = "highlightLaserTrailOpacity"
        static let laserGlow = "highlightLaserGlow"
        static let laserCoreLightness = "highlightLaserCoreLightness"
        static let laserFadeOut = "highlightLaserFadeOut"
        static let laserRim = "highlightLaserRim"
        static let laserShotOn = "highlightLaserShot"
        static let laserShotMargin = "highlightLaserShotMargin"
        static let laserShotTrail = "highlightLaserShotIncludesTrail"
        static let laserShotCopies = "highlightLaserShotCopies"
        static let laserShotSaves = "highlightLaserShotSaves"
        static let laserShotWholeZoom = "highlightLaserShotWholeZoom"
        static let laserShotZoomOut = "highlightLaserShotZoomOut"
        static let laserShotFolder = "highlightLaserShotFolder"
        static let laserShotOpener = "highlightLaserShotOpener"
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
