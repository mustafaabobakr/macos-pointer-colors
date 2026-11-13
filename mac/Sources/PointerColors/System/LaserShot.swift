import AppKit
import OSLog
import ScreenCaptureKit

/// One screenshot of a finished laser trail: where, and what to do with it, as the settings were
/// when the drag ended.
struct LaserShot {
    /// The global area to capture (AppKit points, origin bottom left).
    let area: CGRect
    let includesTrail: Bool
    /// The overlay's windows, left out when the trail isn't wanted in the picture.
    let overlayWindows: [CGWindowID]
    let copies: Bool
    let folder: URL?
    let opener: LaserShotOpener

    /// Nil when screenshots are off, or the drag was too small to be a drawing.
    @MainActor
    init?(settings: PointerHighlight, trail: CGRect, reach: Double, overlayWindows: [CGWindowID]) {
        guard settings.laserShotOn,
              let area = LaserShotArea.area(around: trail, reach: reach, margin: settings.laserShotMargin) else { return nil }
        self.area = area
        includesTrail = settings.laserShotIncludesTrail
        self.overlayWindows = overlayWindows
        copies = settings.laserShotCopies
        folder = settings.laserShotSaves ? URL(filePath: settings.laserShotFolder, directoryHint: .isDirectory) : nil
        opener = settings.laserShotOpener
    }

    private static let log = Logger(subsystem: "PointerColors", category: "LaserShot")

    /// Captures the area and copies, saves and opens it as asked. Failures are logged: there's
    /// nobody to tell mid-drawing, and the next drawing tries again.
    @MainActor
    func take() async {
        do {
            let image = try await capture()
            try deliver(image)
        } catch {
            Self.log.error("Laser screenshot failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    enum Failure: LocalizedError {
        case offScreen, noDisplay, noImage

        var errorDescription: String? {
            switch self {
            case .offScreen: "The trail isn't on any display."
            case .noDisplay: "Screen capture doesn't list the display."
            case .noImage: "The screenshot couldn't be made into a PNG."
            }
        }
    }

    // MARK: Capture

    @MainActor
    private func capture() async throws -> CGImage {
        let screens = NSScreen.screens
        guard let index = LaserShotArea.displayIndex(for: area, among: screens.map(\.frame)),
              let source = LaserShotArea.sourceRect(area, on: screens[index].frame),
              let displayID = screens[index].displayID else { throw Failure.offScreen }
        let scale = screens[index].backingScaleFactor
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { throw Failure.noDisplay }
        let hidden = includesTrail ? [] : content.windows.filter { overlayWindows.contains($0.windowID) }
        let filter = SCContentFilter(display: display, excludingWindows: hidden)
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = source
        configuration.width = Int(source.width * scale)
        configuration.height = Int(source.height * scale)
        configuration.showsCursor = false
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    // MARK: Deliver

    @MainActor
    private func deliver(_ image: CGImage) throws {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw Failure.noImage
        }
        if copies {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setData(png, forType: .png)
        }
        // Opened without saving: kept in the app's own folder, which Preferences can show and empty.
        guard let folder = try folder.map(Self.prepared) ?? (opener == .none ? nil : LaserShotStore().prepared()) else { return }
        let file = Self.freeName(in: folder)
        try png.write(to: file)
        opener.open(file)
    }

    private static func prepared(_ folder: URL) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// "Laser 2026-11-13 at 14.05.33.png", with a number added if that's taken.
    private static func freeName(in folder: URL) -> URL {
        let stamp = Date.now.formatted(.verbatim("\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) at \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)).\(minute: .twoDigits).\(second: .twoDigits)",
                                                 timeZone: .current, calendar: Calendar(identifier: .gregorian)))
        let base = String(localized: "Laser \(stamp)")
        var file = folder.appending(path: base + ".png")
        var number = 2
        while FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            file = folder.appending(path: "\(base) \(number).png")
            number += 1
        }
        return file
    }
}

extension NSScreen {
    /// The display's Core Graphics number, as screen capture names displays.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
