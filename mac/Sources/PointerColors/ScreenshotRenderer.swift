import AppKit
import SwiftUI

/// Developer tool: `PointerColors --render-screenshot out.png` draws the menu offscreen into a PNG
/// for the website and README, then quits. It uses AppKit's own drawing (not ImageRenderer) so
/// sliders, toggles and buttons render as they do on screen. Needs no Screen Recording permission.
@MainActor
enum ScreenshotRenderer {
    static let flag = "--render-screenshot"

    /// The output path when the app was launched to render a screenshot.
    static var requestedPath: String? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    static func render(model: AppModel, to path: String) {
        let content = MenuContentView(model: model)
            .background(Color(red: 0.114, green: 0.122, blue: 0.141))
        let host = NSHostingView(rootView: content)
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame.size = host.fittingSize

        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()

        let ok = write(host, to: URL(fileURLWithPath: path))
        print(ok ? "Wrote \(path) (\(Int(host.bounds.width))×\(Int(host.bounds.height)) pt)" : "Couldn't render \(path)")
        exit(ok ? 0 : 1)
    }

    /// Retina-sharp: 2 pixels per point, whatever screen (if any) the offscreen window is on.
    private static let pixelsPerPoint: CGFloat = 2

    private static func write(_ view: NSView, to url: URL) -> Bool {
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
