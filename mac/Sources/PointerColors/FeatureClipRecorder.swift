import AppKit
import SwiftUI

/// Developer tool: `PointerColors --record-feature <id> <screen> <spot> <dir> [--app-icon …]`
/// plays feature `id`'s demo (FeatureClipScripts) on its screen offscreen, then quits. Like the
/// screenshots it needs no Screen Recording permission and never changes the real pointer.
///
/// Into `dir` it writes the whole screen before (`start.png`) and after (`end.png`), the
/// feature's area (or the whole screen) frame by frame (`frames/`), the menu bar icon for each
/// pair shown (`icons/`), and `clip.json` with where the feature is, what the frames cover, and
/// for each frame where the pointer was with its colors and size, the theme, and any shortcut. mac/scripts/feature-clips.sh runs it
/// for each feature and docs/art/make_feature_clips.py turns the result into the clip.
@MainActor
final class FeatureClipRecorder {
    nonisolated static let flag = "--record-feature"
    static let fps = 25.0
    static let pixelsPerPoint: CGFloat = 2
    /// The clips are 16:10, so the area recorded around a feature is too.
    static let aspect = 1.6
    /// Points of the screen kept around a feature.
    static let padding: CGFloat = 14

    struct Request {
        let id: String
        let screen: String
        let spot: String
        let folder: URL
    }

    static var request: Request? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), args.count > index + 4 else { return nil }
        return Request(id: args[index + 1], screen: args[index + 2], spot: args[index + 3],
                       folder: URL(fileURLWithPath: args[index + 4]))
    }

    static func record(_ request: Request, model: AppModel) {
        ScreenshotRenderer.useAppIcon()
        Task { @MainActor in
            let ok = await FeatureClipRecorder(request: request, model: model)?.run() ?? false
            print(ok ? "Recorded \(request.id) into \(request.folder.path)" : "Couldn't record \(request.id)")
            exit(ok ? 0 : 1)
        }
    }

    let request: Request
    let model: AppModel
    let clip: FeatureClip
    private var host: NSHostingView<AnyView>!
    private var focus = CGRect.zero
    private var capture = CGRect.zero
    /// The keycaps on screen, while a shortcut step plays.
    private var keys = ""
    private var start = Date()
    private var frames: [[Any]] = []
    private var writes: [Task<Bool, Never>] = []
    private var icons: Set<String> = []
    /// The pointer, in the screen's points from the top left, and whether its button is down.
    private(set) var cursor = CGPoint.zero
    private(set) var isPressed = false

    private init?(request: Request, model: AppModel) {
        guard let clip = FeatureClipScripts.all[request.id] else {
            print("No script for \(request.id) in FeatureClipScripts")
            return nil
        }
        self.request = request
        self.model = model
        self.clip = clip
    }

    private func run() async -> Bool {
        let fileManager = FileManager.default
        let framesFolder = request.folder.appendingPathComponent("frames")
        try? fileManager.removeItem(at: request.folder)
        try? fileManager.createDirectory(at: framesFolder, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: request.folder.appendingPathComponent("icons"), withIntermediateDirectories: true)
        clip.setUp(model)
        guard let screen = ScreenshotRenderer.screens(model).first(where: { $0.name == request.screen }) else {
            print("No screen named \(request.screen)")
            return false
        }
        FeatureSpots.reset()
        host = ScreenshotRenderer.makeHost(screen.view(), height: screen.height)
        try? await Task.sleep(for: .milliseconds(600))
        host.layoutSubtreeIfNeeded()
        let spotID = clip.focusesOn ?? request.spot
        guard let spot = FeatureSpots.frames[spotID] else {
            print("No .featureSpot(\"\(spotID)\") on \(request.screen)")
            return false
        }
        focus = area(around: clip.alsoShows.compactMap { FeatureSpots.frames[$0] }.reduce(spot) { $0.union($1) })
        capture = clip.recordsWholeScreen ? host.bounds : focus
        cursor = point(clip.cursorStart)
        ClipPointer.shared.location = cursor
        try? await Task.sleep(for: .milliseconds(100))
        var ok = writeScreen("start.png")
        start = Date()
        for step in clip.steps { await perform(step) }
        ok = writeScreen("end.png") && ok
        for write in writes { ok = await write.value && ok }
        return writeInfo() && ok
    }

    // MARK: Steps

    private func perform(_ step: ClipStep) async {
        switch step {
        case .pause(let seconds): await frames(for: seconds)
        case .move(let target, let seconds): await glide(to: point(target), seconds: seconds, sending: nil)
        case .click: await click()
        case .hold(let seconds): await hold(seconds)
        case .drag(let targets, let seconds): await drag(through: targets.map(point), seconds: seconds)
        case .choose(let change): await choose(change)
        case .slide(let target, let seconds, let change): await slide(to: point(target), seconds: seconds, change: change)
        case .act(let change): change(model)
        case .keys(let label, let change): await shortcut(label, change)
        }
    }

    private func frames(for seconds: Double) async {
        for _ in 0..<frameCount(seconds) { await tick() }
    }

    /// Moves the pointer along an eased path, one frame at a time.
    private func glide(to target: CGPoint, seconds: Double, sending type: NSEvent.EventType?,
                       each: ((Double) -> Void)? = nil) async {
        let from = cursor
        let count = frameCount(seconds)
        for index in 1...count {
            let progress = Self.eased(Double(index) / Double(count))
            cursor = CGPoint(x: from.x + (target.x - from.x) * progress, y: from.y + (target.y - from.y) * progress)
            ClipPointer.shared.location = cursor
            if let type { send(type) }
            each?(progress)
            await tick()
        }
    }

    /// An AppKit control under the pointer is clicked directly: the offscreen window is never
    /// active, so it would take a real click as the one that activates it. Anything else, like
    /// the demo pad, gets real mouse events.
    private func click() async {
        isPressed = true
        let control = host.hitTest(CGPoint(x: cursor.x, y: host.bounds.height - cursor.y)) as? NSControl
        if control == nil { send(.leftMouseDown) }
        await frames(for: 0.12)
        isPressed = false
        if let control { control.performClick(nil) } else { send(.leftMouseUp) }
        await frames(for: 0.1)
    }

    private func shortcut(_ label: String, _ change: (AppModel) -> Void) async {
        keys = label
        await frames(for: 0.15)
        change(model)
        await frames(for: 0.85)
        keys = ""
    }

    private func choose(_ change: (AppModel) -> Void) async {
        isPressed = true
        await frames(for: 0.12)
        isPressed = false
        change(model)
        await frames(for: 0.1)
    }

    private func hold(_ seconds: Double) async {
        press()
        await frames(for: seconds)
        release()
    }

    private func drag(through targets: [CGPoint], seconds: Double) async {
        press()
        for target in targets { await glide(to: target, seconds: seconds / Double(targets.count), sending: .leftMouseDragged) }
        release()
    }

    /// A slider follows the pointer: the model changes as it moves, without real mouse events,
    /// which would start AppKit's own tracking loop and stop the frames.
    private func slide(to target: CGPoint, seconds: Double, change: @escaping (AppModel, Double) -> Void) async {
        isPressed = true
        await glide(to: target, seconds: seconds, sending: nil) { [model] in change(model, $0) }
        isPressed = false
    }

    private func press() {
        isPressed = true
        send(.leftMouseDown)
    }

    private func release() {
        isPressed = false
        send(.leftMouseUp)
    }

    // MARK: Frames

    private func frameCount(_ seconds: Double) -> Int { max(1, Int((seconds * Self.fps).rounded())) }

    /// Waits for the next frame's moment, so animations play at their real speed, then saves it.
    private func tick() async {
        let due = start.addingTimeInterval(Double(frames.count) / Self.fps)
        let wait = due.timeIntervalSinceNow
        if wait > 0 { try? await Task.sleep(for: .seconds(wait)) } else { await Task.yield() }
        followTheme()
        host.layoutSubtreeIfNeeded()
        let name = String(format: "frames/%05d.png", frames.count)
        writes.append(saveInBackground(image(of: capture), to: request.folder.appendingPathComponent(name)))
        let pair = model.menuBarPair
        frames.append([cursor.x, cursor.y, isPressed, model.scale, pair.outline.hex, pair.fill.hex, icon(for: pair),
                       model.colorScheme == .dark, keys])
    }

    /// The window was made dark for the screenshots; a clip that changes the theme changes it.
    private func followTheme() {
        let appearance = NSAppearance(named: model.colorScheme == .dark ? .darkAqua : .aqua)
        guard host.appearance != appearance else { return }
        host.appearance = appearance
        host.window?.appearance = appearance
    }

    private func image(of rect: CGRect) -> CGImage? {
        let pixels = Self.pixelsPerPoint
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(rect.width * pixels), pixelsHigh: Int(rect.height * pixels),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = rect.size
        host.cacheDisplay(in: rect, to: rep)
        return rep.cgImage
    }

    /// PNG encoding is slow next to a frame's 40 ms, so it happens off the main thread.
    private func saveInBackground(_ image: CGImage?, to url: URL) -> Task<Bool, Never> {
        Task.detached(priority: .userInitiated) {
            guard let image,
                  let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
            else { return false }
            CGImageDestinationAddImage(destination, image, nil)
            return CGImageDestinationFinalize(destination)
        }
    }

    /// The menu bar icon for `pair`, saved the first time it's shown. Returns its file name.
    private func icon(for pair: PointerPair) -> String {
        let name = "icons/\(pair.outline.hex)-\(pair.fill.hex)\(model.iconInPairColors ? "" : "-plain").png"
        guard icons.insert(name).inserted else { return name }
        let glyph = model.iconInPairColors
            ? AnyView(PointerGlyph(pair: pair, lineWidth: 1.4))
            : AnyView(PointerShape().fill(Color.white))
        let renderer = ImageRenderer(content: glyph.frame(width: 13, height: 16).padding(1))
        renderer.scale = 4
        writes.append(saveInBackground(renderer.cgImage, to: request.folder.appendingPathComponent(name)))
        return name
    }

    private func writeScreen(_ name: String) -> Bool {
        host.layoutSubtreeIfNeeded()
        return ScreenshotRenderer.write(host, to: request.folder.appendingPathComponent(name), scale: Self.pixelsPerPoint)
    }

    private func writeInfo() -> Bool {
        let info: [String: Any] = [
            "fps": Self.fps,
            "pixelsPerPoint": Double(Self.pixelsPerPoint),
            "screen": [host.bounds.width, host.bounds.height],
            "focus": [focus.minX, focus.minY, focus.width, focus.height],
            "capture": [capture.minX, capture.minY, capture.width, capture.height],
            // A Preferences tab's tab bar stays put while the tab scrolls.
            "header": FeatureSpots.frames["clip-tab-bar"].map { $0.maxY + 1 } ?? 0,
            "frames": frames,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted]) else { return false }
        return (try? data.write(to: request.folder.appendingPathComponent("clip.json"))) != nil
    }

    // MARK: Geometry

    /// The feature with room around it, widened or heightened to the clip's shape and kept on
    /// the screen, in points from the top left.
    private func area(around spot: CGRect) -> CGRect {
        var rect = spot.insetBy(dx: -Self.padding, dy: -Self.padding)
        if rect.width / rect.height < Self.aspect {
            rect = rect.insetBy(dx: -(rect.height * Self.aspect - rect.width) / 2, dy: 0)
        } else {
            rect = rect.insetBy(dx: 0, dy: -(rect.width / Self.aspect - rect.height) / 2)
        }
        return Self.kept(rect, inside: host.bounds).integral
    }

    /// Slides `rect` inside `bounds`, cutting it down only where it's bigger.
    private static func kept(_ rect: CGRect, inside bounds: CGRect) -> CGRect {
        let width = min(rect.width, bounds.width), height = min(rect.height, bounds.height)
        let x = min(max(rect.midX - width / 2, bounds.minX), bounds.maxX - width)
        let y = min(max(rect.midY - height / 2, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// A point on a marked view, as a fraction of its frame.
    private func point(_ target: ClipPoint) -> CGPoint {
        guard let frame = FeatureSpots.frames[target.spot] else {
            print("warning: no .featureSpot(\"\(target.spot)\") for the pointer; it stays put")
            return cursor
        }
        return CGPoint(x: frame.minX + frame.width * target.x, y: frame.minY + frame.height * target.y)
    }

    private static func eased(_ t: Double) -> Double { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

    // MARK: Events

    /// A mouse event at the pointer, straight to the offscreen window.
    private func send(_ type: NSEvent.EventType) {
        guard let event = event(type) else { return }
        host.window?.sendEvent(event)
    }

    private func event(_ type: NSEvent.EventType) -> NSEvent? {
        guard let window = host.window else { return nil }
        let location = CGPoint(x: cursor.x, y: host.bounds.height - cursor.y)
        return NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                                  timestamp: ProcessInfo.processInfo.systemUptime,
                                  windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                  clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)
    }
}
