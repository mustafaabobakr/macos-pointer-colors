import CoreGraphics

/// A point on a view marked with `.featureSpot`, as a fraction of its frame from the top left.
struct ClipPoint {
    let spot: String
    var x = 0.5
    var y = 0.5
}

/// One step of a feature's demo. The pointer is drawn into the clip afterwards, in the colors and
/// size of the pair on screen at that frame.
enum ClipStep {
    case pause(Double)
    /// The pointer glides to a point.
    case move(to: ClipPoint, seconds: Double = 0.7)
    /// A real click: SwiftUI views like the highlight demo pad follow it, and so do plain buttons.
    case click
    /// A real press held down, then let go.
    case hold(Double)
    /// A real drag from the pointer through each point in turn.
    case drag(through: [ClipPoint], seconds: Double)
    /// A click on an AppKit control (picker, toggle, button), shown by the pointer while the
    /// change is made on the model. Real events would start the control's own tracking loop.
    case choose((AppModel) -> Void)
    /// Drags a slider: the pointer moves with the button down while the change follows it,
    /// called with 0 to 1 of the way.
    case slide(to: ClipPoint, seconds: Double, change: (AppModel, Double) -> Void)
    /// A change with no pointer action, like a display switch.
    case act((AppModel) -> Void)
    /// A keyboard shortcut, shown as keycaps while its change is made.
    case keys(String, (AppModel) -> Void)
}

/// A feature's demo: where the pointer starts, what it does, and any marked views besides the
/// feature's own (or instead of it, `focusesOn`) that must stay in the picture. A demo that
/// changes the whole window, like its theme, records all of it.
struct FeatureClip {
    var cursorStart: ClipPoint
    var focusesOn: String?
    var alsoShows: [String] = []
    var recordsWholeScreen = false
    var setUp: (AppModel) -> Void = { _ in }
    var steps: [ClipStep]
}

/// The demo for each feature in docs/features/features.json, by id. Views a demo points at are
/// marked `.featureSpot("clip-…")`.
@MainActor
enum FeatureClipScripts {
    static let all: [String: FeatureClip] = [
        "menu-pairs": menuPairs, "current-pair": currentPair, "pointer-size": pointerSize,
        "previews": previews, "display-colors": displayColors, "menu-highlight": menuHighlight,
        "custom-pairs": customPairs, "appearance-pairs": appearancePairs, "app-colors": appColors,
        "highlight": highlight, "press-shrink": pressShrink, "pulse": pulse, "laser": laser, "highlight-pair-colors": highlightPairColors,
        "shortcuts": shortcuts, "menu-appearance": menuAppearance, "backup": backup,
        "update-window": updateWindow, "updates": updates,
    ]

    // MARK: Helpers

    /// Picks a pair the way a click on its tile in the menu does.
    private static func pick(_ id: String) -> ClipStep {
        .choose { model in model.library.pair(id: id).map(model.choose) }
    }

    /// Puts a pair on screen as if picked elsewhere, with no pointer action.
    private static func show(_ id: String) -> ClipStep {
        .act { model in model.library.pair(id: id).map(model.choose) }
    }

    private static func tile(_ id: String) -> ClipPoint { ClipPoint(spot: "clip-pair-\(id)") }

    private static func spot(_ id: String, x: Double = 0.5, y: Double = 0.5) -> ClipPoint {
        ClipPoint(spot: id, x: x, y: y)
    }

    /// Where a value sits along a slider marked `spot`, between the end labels it may have.
    private static func along(_ spot: String, _ value: Double, in range: ClosedRange<Double>,
                              inset: Double = 0.06) -> ClipPoint {
        let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return ClipPoint(spot: spot, x: inset + (1 - 2 * inset) * fraction, y: 0.5)
    }

    private static func lerp(_ from: Double, _ to: Double, _ progress: Double) -> Double {
        from + (to - from) * progress
    }

    private static let pad = "clip-demo-pad"
    private static let sizes = SystemPointer.minimumScale...SystemPointer.maximumScale
    private static let demoScale = 2.21

    // MARK: Menu

    private static let menuPairs = FeatureClip(
        cursorStart: ClipPoint(spot: "clip-pair-aqua-mint", x: 0.7, y: 0.8),
        steps: [
            .pause(0.5),
            .move(to: tile("neon-pink")), pick("neon-pink"), .pause(0.8),
            .move(to: tile("electric-blue")), pick("electric-blue"), .pause(0.8),
            .move(to: tile("neon-lime")), pick("neon-lime"), .pause(0.8),
            .move(to: tile("neon-orange")), pick("neon-orange"), .pause(1.0),
        ])

    private static let currentPair = FeatureClip(
        cursorStart: spot("current-pair", x: 0.85, y: 0.85),
        steps: [
            .pause(0.6), show("neon-pink"), .pause(1.0),
            show("sakura"), .pause(1.8),
            .move(to: spot("current-pair", x: 0.62, y: 0.4)), .pause(0.6),
            show("electric-blue"), .pause(1.2),
        ])

    private static let pointerSize = FeatureClip(
        cursorStart: along("clip-size-slider", demoScale, in: sizes),
        steps: [
            .pause(0.5),
            .slide(to: along("clip-size-slider", 3.6, in: sizes), seconds: 1.4) { $0.setScale(lerp(demoScale, 3.6, $1)) },
            .pause(0.6),
            .slide(to: along("clip-size-slider", 1.4, in: sizes), seconds: 1.4) { $0.setScale(lerp(3.6, 1.4, $1)) },
            .pause(0.6),
            .slide(to: along("clip-size-slider", demoScale, in: sizes), seconds: 0.8) { $0.setScale(lerp(1.4, demoScale, $1)) },
            .pause(0.8),
        ])

    private static let previews = FeatureClip(
        cursorStart: ClipPoint(spot: "clip-pair-aqua-mint", x: 0.7, y: 0.8),
        alsoShows: ["menu-pairs"],
        steps: [
            .pause(0.5),
            .move(to: tile("neon-yellow")), pick("neon-yellow"), .pause(1.0),
            .move(to: tile("neon-violet")), pick("neon-violet"), .pause(1.0),
            .move(to: tile("neon-red")), pick("neon-red"), .pause(1.2),
        ])

    private static let displayColors = FeatureClip(
        cursorStart: spot("display-colors", x: 0.5, y: 0.2),
        steps: [
            .pause(0.4),
            .move(to: spot("clip-display-demo-studio", x: 0.85)),
            .choose { $0.automation.setPair("neon-pink", for: DisplayInfo.demo[1]) }, .pause(0.6),
            // Off the right edge, onto the other display, and back.
            .move(to: spot("display-colors", x: 1.25, y: 0.5), seconds: 0.6),
            .act { $0.automation.simulatePointer(onDisplay: DisplayInfo.demo[1]) },
            .move(to: spot("display-colors", x: 0.7, y: 0.45), seconds: 0.6), .pause(1.2),
            .move(to: spot("display-colors", x: 1.25, y: 0.5), seconds: 0.6),
            .act { $0.automation.simulatePointer(onDisplay: DisplayInfo.demo[0]) },
            .move(to: spot("display-colors", x: 0.7, y: 0.45), seconds: 0.6), .pause(1.0),
        ])

    private static let menuHighlight = FeatureClip(
        cursorStart: spot("menu-highlight", x: 0.5, y: 0.2),
        steps: [
            .pause(0.4),
            .move(to: spot("clip-card-pulse")), .choose { $0.highlight.setOn(false, .pulse) }, .pause(0.7),
            .choose { $0.highlight.setOn(true, .pulse) }, .pause(0.5),
            .move(to: spot("clip-card-laser")), .choose { $0.highlight.setOn(false, .laser) }, .pause(0.7),
            .choose { $0.highlight.setOn(true, .laser) }, .pause(1.0),
        ])

    // MARK: Preferences

    private static let customPairs = FeatureClip(
        cursorStart: spot("custom-pairs", x: 0.5, y: 0.3),
        recordsWholeScreen: true,
        steps: [
            .pause(0.4),
            .move(to: spot("clip-row-macos-light", x: 0.95)),
            .choose { model in model.library.pair(id: "macos-light").map { model.setHidden(true, pair: $0) } },
            .pause(0.6),
            .choose { model in model.library.pair(id: "macos-light").map { model.setHidden(false, pair: $0) } },
            .pause(0.4),
            .move(to: spot("clip-add-custom")), .click, .pause(2.0),
        ])

    private static let appearancePairs = FeatureClip(
        cursorStart: spot("clip-follows-appearance", x: 0.6, y: 0.6),
        recordsWholeScreen: true,
        steps: [
            .pause(0.8),
            .act { $0.theme = .light; $0.automation.simulateAppearance(dark: false) }, .pause(1.6),
            .act { $0.theme = .dark; $0.automation.simulateAppearance(dark: true) }, .pause(1.4),
        ])

    private static let appColors = FeatureClip(
        cursorStart: spot("clip-app-trigger", x: 0.3),
        steps: [
            .pause(0.4),
            .move(to: spot("clip-app-com.apple.Safari", x: 0.3)),
            .act { $0.automation.simulatePointer(overApp: "com.apple.Safari") }, .pause(0.9),
            .move(to: spot("clip-app-com.apple.Terminal", x: 0.3)),
            .act { $0.automation.simulatePointer(overApp: "com.apple.Terminal") }, .pause(0.9),
            .move(to: spot("clip-app-com.apple.finder", x: 0.3)),
            .act { $0.automation.simulatePointer(overApp: "com.apple.finder") }, .pause(0.9),
            .move(to: spot("clip-app-trigger", x: 0.3)),
            .act { $0.automation.simulatePointer(overApp: nil) }, .pause(0.8),
        ])

    private static let highlight = FeatureClip(
        cursorStart: spot(pad, x: 0.8, y: 0.7),
        setUp: { $0.highlight.laserNeedsKeys = false },
        steps: [
            .pause(0.4),
            .move(to: spot(pad, x: 0.25, y: 0.5)), .click, .pause(0.6),
            .drag(through: [spot(pad, x: 0.4, y: 0.25), spot(pad, x: 0.55, y: 0.7), spot(pad, x: 0.75, y: 0.35)],
                  seconds: 1.2),
            .pause(0.6),
            .move(to: spot("clip-card-laser")), .choose { $0.highlight.setOn(false, .laser) },
            .move(to: spot(pad, x: 0.6, y: 0.5)), .click, .pause(0.6),
            .move(to: spot("clip-card-laser")), .choose { $0.highlight.setOn(true, .laser) }, .pause(0.6),
        ])

    private static let pressShrink = FeatureClip(
        cursorStart: spot("press-shrink", x: 0.6, y: 0.9),
        setUp: { $0.highlight.shrinksOnPress = false },
        steps: [
            .pause(0.4),
            .move(to: spot("clip-press-toggle", x: 0.95)), .choose { $0.highlight.shrinksOnPress = true }, .pause(0.5),
            .click, .pause(0.4), .hold(0.6), .pause(0.4),
            .move(to: along("clip-press-size", 0.88, in: PointerHighlight.pressScaleRange, inset: 0.3)),
            .slide(to: along("clip-press-size", 0.7, in: PointerHighlight.pressScaleRange, inset: 0.3), seconds: 0.8) {
                $0.highlight.pressScale = lerp(0.88, 0.7, $1)
            },
            .move(to: spot("clip-press-curve", x: 0.85)), .choose { $0.highlight.pressCurve = .bounce }, .pause(0.8),
        ])

    private static let pulse = FeatureClip(
        cursorStart: spot(pad, x: 0.8, y: 0.7),
        alsoShows: [pad],
        setUp: { $0.highlight.pulseStyle = .ring },
        steps: [
            .pause(0.4),
            .move(to: spot(pad, x: 0.3)), .click, .pause(0.5),
            .move(to: spot(pad, x: 0.65, y: 0.4), seconds: 0.5), .click, .pause(0.6),
            .move(to: spot("clip-pulse-style", x: 0.75)), .choose { $0.highlight.pulseStyle = .ripple },
            .move(to: spot(pad, x: 0.45, y: 0.55)), .click, .pause(0.9),
            .move(to: along("clip-pulse-size", 1.0, in: PointerHighlight.sizeRange, inset: 0.3)),
            .slide(to: along("clip-pulse-size", 1.8, in: PointerHighlight.sizeRange, inset: 0.3), seconds: 0.8) {
                $0.highlight.pulseSize = lerp(1.0, 1.8, $1)
            },
            .move(to: spot(pad, x: 0.5)), .hold(1.0), .pause(1.0),
        ])

    /// The laser section is too tall to frame with the pad, so this one stays on the pad.
    private static let laser = FeatureClip(
        cursorStart: spot(pad, x: 0.2, y: 0.5),
        focusesOn: pad,
        setUp: { $0.highlight.laserNeedsKeys = false },
        steps: [
            .pause(0.4),
            .drag(through: [spot(pad, x: 0.35, y: 0.2), spot(pad, x: 0.5, y: 0.75), spot(pad, x: 0.65, y: 0.25),
                            spot(pad, x: 0.8, y: 0.6)], seconds: 1.6),
            .pause(0.8),
            .act { $0.highlight.laserOutline = .laser },
            .move(to: spot(pad, x: 0.2, y: 0.7)),
            .drag(through: [spot(pad, x: 0.45, y: 0.3), spot(pad, x: 0.7, y: 0.7), spot(pad, x: 0.85, y: 0.3)],
                  seconds: 1.3),
            .pause(1.2),
        ])

    private static let highlightPairColors = FeatureClip(
        cursorStart: spot("highlight-pair-colors", x: 0.5, y: 0.2),
        steps: [
            .pause(0.4),
            .move(to: spot("clip-pair-pulse-color", x: 0.93)),
            .choose { model in model.highlight.setPulseColor(RGBA(red: 1, green: 0.3, blue: 0.6), for: model.menuBarPair) },
            .pause(1.0),
            .move(to: spot("highlight-pair-colors", x: 0.6, y: 0.3)), show("neon-lime"), .pause(1.2),
            show("aqua-mint"), .pause(0.8),
        ])

    private static let shortcuts = FeatureClip(
        cursorStart: spot("shortcuts", x: 0.3, y: 0.55),
        steps: [
            .pause(0.4),
            .keys("⌃ ⌥ →") { $0.perform(.nextPair) }, .pause(0.2),
            .keys("⌃ ⌥ →") { $0.perform(.nextPair) }, .pause(0.2),
            .keys("⌃ ⌥ ←") { $0.perform(.previousPair) }, .pause(0.2),
            .keys("⌃ ⌥ =") { $0.perform(.biggerPointer) }, .pause(0.2),
            .keys("⌃ ⌥ =") { $0.perform(.biggerPointer) }, .pause(0.2),
            .keys("⌃ ⌥ -") { $0.perform(.smallerPointer) }, .pause(0.6),
        ])

    private static let menuAppearance = FeatureClip(
        cursorStart: spot("menu-appearance", x: 0.4, y: 0.1),
        recordsWholeScreen: true,
        steps: [
            .pause(0.4),
            .move(to: spot("clip-theme", x: 0.73)), .choose { $0.theme = .light }, .pause(1.4),
            .move(to: spot("clip-theme", x: 0.92)), .choose { $0.theme = .dark }, .pause(1.2),
        ])

    private static let backup = FeatureClip(
        cursorStart: spot("backup", x: 0.3, y: 0.7),
        steps: [
            .pause(0.4),
            .move(to: spot("clip-export", x: -0.8)), .pause(0.6),
            .move(to: spot("clip-export"), seconds: 0.5), .choose { _ in }, .pause(1.0),
        ])

    private static let updateWindow = FeatureClip(
        cursorStart: spot("update-window", x: 0.6, y: 0.45),
        steps: [
            .pause(0.6),
            .move(to: spot("clip-skip")), .pause(0.7),
            .move(to: spot("clip-install-on-quit")), .pause(0.7),
            .move(to: spot("clip-install")), .pause(1.2),
        ])

    private static let updates = FeatureClip(
        cursorStart: spot("updates", x: 0.5, y: 0.9),
        recordsWholeScreen: true,
        steps: [
            .pause(0.4),
            .move(to: spot("clip-check-updates")), .choose { ScreenshotRenderer.showDemoUpdate($0) }, .pause(2.2),
        ])
}
