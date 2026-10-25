import AppKit
import SwiftUI

/// Developer tool, two modes, each drawing offscreen and then quitting. It uses AppKit's own
/// drawing (not ImageRenderer) so sliders, toggles and buttons render as they do on screen, and
/// needs no Screen Recording permission. While it runs the real pointer is never changed.
///
/// - `PointerColors --render-screenshot out.png` draws the menu for the website and README.
/// - `PointerColors --render-features dir` draws the menu and every Preferences tab into `dir`,
///   with `spots.json` giving where each `featureSpot` is. mac/scripts/feature-screenshots.sh
///   runs it with demo settings and frames the spots into docs/features.
@MainActor
enum ScreenshotRenderer {
    nonisolated static let flag = "--render-screenshot"
    nonisolated static let featuresFlag = "--render-features"

    /// True when the app was launched for either mode. Read before the model is created.
    nonisolated static var isRendering: Bool {
        CommandLine.arguments.contains(flag) || CommandLine.arguments.contains(featuresFlag)
    }

    /// The output path when the app was launched to render a screenshot.
    static var requestedPath: String? { argument(after: flag) }

    /// The output folder when the app was launched to render feature screenshots.
    static var requestedFeaturesFolder: String? { argument(after: featuresFlag) }

    private static func argument(after flag: String) -> String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static func render(model: AppModel, to path: String) {
        let host = makeHost(menu(model), height: nil)
        let ok = write(host, to: URL(fileURLWithPath: path))
        print(ok ? "Wrote \(path) (\(Int(host.bounds.width))×\(Int(host.bounds.height)) pt)" : "Couldn't render \(path)")
        exit(ok ? 0 : 1)
    }

    // MARK: Feature screenshots

    /// One picture per screen; features are framed from these by their spots.
    private static func screens(_ model: AppModel) -> [(name: String, view: AnyView, height: CGFloat?)] {
        let tabs: [(PreferencesTab, CGFloat)] = [(.general, 860), (.pairs, 520), (.automation, 760),
                                                (.highlight, 1500), (.shortcuts, 420), (.about, 760)]
        return [("menu", menu(model), nil)]
            + tabs.map { tab, height in
                let view = PreferencesView(model: model, tab: tab).background(Color(nsColor: .windowBackgroundColor))
                return ("preferences-\(tab.slug)", AnyView(view), height)
            }
    }

    static func renderFeatures(model: AppModel, into folder: String) {
        Task { @MainActor in
            let dir = URL(fileURLWithPath: folder)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            var spots: [String: [String: [Double]]] = ["_render": ["pixelsPerPoint": [featurePixelsPerPoint]]]
            var ok = true
            for screen in screens(model) {
                FeatureSpots.reset()
                let host = makeHost(screen.view, height: screen.height)
                // Lets onAppear run and lazy content settle before drawing.
                try? await Task.sleep(for: .milliseconds(600))
                host.layoutSubtreeIfNeeded()
                ok = write(host, to: dir.appendingPathComponent("\(screen.name).png"), scale: featurePixelsPerPoint) && ok
                spots[screen.name] = FeatureSpots.frames.mapValues { [$0.minX, $0.minY, $0.width, $0.height] }
                spots[screen.name]?["_screen"] = [0, 0, host.bounds.width, host.bounds.height]
                host.window?.orderOut(nil)
            }
            let json = try? JSONSerialization.data(withJSONObject: spots, options: [.prettyPrinted, .sortedKeys])
            ok = ((try? json?.write(to: dir.appendingPathComponent("spots.json"))) != nil) && ok
            print(ok ? "Wrote \(spots.count - 1) screens to \(folder)" : "Couldn't render into \(folder)")
            exit(ok ? 0 : 1)
        }
    }

    // MARK: Drawing

    private static func menu(_ model: AppModel) -> AnyView {
        AnyView(MenuContentView(model: model).background(Color(red: 0.114, green: 0.122, blue: 0.141)))
    }

    /// A borderless offscreen window holding `view`, at its fitting size or the given height.
    private static func makeHost(_ view: AnyView, height: CGFloat?) -> NSHostingView<AnyView> {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame.size = host.fittingSize
        if let height { host.frame.size.height = height }

        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        // On screen but fully transparent and click-through: lazy grids only fill in for a window
        // that's showing, and nothing is visible to the person at the Mac.
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        return host
    }

    /// Retina-sharp: 2 pixels per point, whatever screen (if any) the offscreen window is on.
    nonisolated private static let pixelsPerPoint: CGFloat = 2
    /// Feature screenshots are zoomed in, so they're drawn sharper.
    private static let featurePixelsPerPoint: CGFloat = 3

    private static func write(_ view: NSView, to url: URL, scale pixelsPerPoint: CGFloat = pixelsPerPoint) -> Bool {
        let size = view.bounds.size
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                         pixelsWide: Int(size.width * pixelsPerPoint),
                                         pixelsHigh: Int(size.height * pixelsPerPoint),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return false }
        rep.size = size
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }
}
