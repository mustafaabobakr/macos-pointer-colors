import CoreGraphics
import Foundation
import Testing
@testable import PointerColors

struct LensPlacementTests {
    let screen = CGSize(width: 1440, height: 900)
    let lens = CGSize(width: 300, height: 168.75)

    private func frame(_ placement: LensPlacement, _ x: CGFloat, _ y: CGFloat) -> CGRect {
        placement.frame(pointer: CGPoint(x: x, y: y), lens: lens, screen: screen)
    }

    @Test func `on the pointer stays centred on it, even past the edge`() {
        #expect(frame(.onPointer, 720, 450) == CGRect(x: 570, y: 365.625, width: 300, height: 168.75))
        #expect(frame(.onPointer, 1430, 10).minX == 1280)
    }

    @Test(arguments: [LensPlacement.quadrants, .edgeBands, .slideAndFlip, .orbit])
    func `the lens never covers the pointer and stays on screen`(placement: LensPlacement) {
        for x in stride(from: 0, through: screen.width - 1, by: 37) {
            for y in stride(from: 0, through: screen.height - 1, by: 29) {
                let lensFrame = frame(placement, x, y)
                #expect(!lensFrame.contains(CGPoint(x: x, y: y)), "\(placement) at \(x), \(y)")
                #expect(CGRect(origin: .zero, size: screen).insetBy(dx: 7.9, dy: 7.9).contains(lensFrame))
            }
        }
    }

    @Test func `quadrants goes up-left in the top-right corner and up-right in the bottom-left`() {
        let topRight = frame(.quadrants, 1400, 300)
        #expect(topRight.maxX == 1400 - LensPlacement.gap && topRight.maxY == 300 - LensPlacement.gap)
        let bottomLeft = frame(.quadrants, 40, 850)
        #expect(bottomLeft.minX == 40 + LensPlacement.gap && bottomLeft.maxY == 850 - LensPlacement.gap)
    }

    @Test(arguments: [LensPlacement.quadrants, .edgeBands, .slideAndFlip])
    func `near the top the lens drops below the pointer`(placement: LensPlacement) {
        #expect(frame(placement, 720, 40).minY == 40 + LensPlacement.gap)
    }

    @Test func `edge bands is straight above in open space and diagonal at the sides`() {
        let middle = frame(.edgeBands, 720, 450)
        #expect(middle.midX == 720 && middle.maxY == 450 - LensPlacement.gap)
        #expect(frame(.edgeBands, 1430, 450).maxX == 1430 - LensPlacement.gap)
        #expect(frame(.edgeBands, 10, 450).minX == 10 + LensPlacement.gap)
    }

    @Test func `slide and flip slides along the edge instead of jumping`() {
        #expect(frame(.slideAndFlip, 1430, 450).maxX == screen.width - LensPlacement.margin)
    }

    @Test func `orbit is straight above in the middle of the screen`() {
        let middle = frame(.orbit, 720, 600)
        #expect(abs(middle.midX - 720) < 0.001 && middle.maxY < 600)
    }

    @Test func `glide lands at once first, then eases, then settles`() {
        var glide = LensGlide()
        #expect(glide.step(toward: CGVector(dx: 10, dy: 10), after: 0, snaps: false) == CGVector(dx: 10, dy: 10))
        let halfway = glide.step(toward: CGVector(dx: 110, dy: 10), after: LensGlide.halfLife, snaps: false)
        #expect(abs(halfway.dx - 60) < 0.001)
        #expect(glide.step(toward: CGVector(dx: 110, dy: 10), after: 1, snaps: false) == CGVector(dx: 110, dy: 10))
        #expect(glide.step(toward: .zero, after: 0.001, snaps: true) == .zero)
    }

    @MainActor
    @Test func `on the pointer by default, and saved`() throws {
        let name = "LensPlacementTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let zoom = MagicMouseZoom(defaults: defaults)
        #expect(zoom.lensPlacement == .onPointer)
        zoom.lensPlacement = .edgeBands
        #expect(MagicMouseZoom(defaults: defaults).lensPlacement == .edgeBands)
    }

    @MainActor
    @Test func `settings backup carries the placement`() throws {
        let name = "LensPlacementBackup-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let folder = FileManager.default.temporaryDirectory.appending(path: name)
        defer { try? FileManager.default.removeItem(at: folder) }
        MagicMouseZoom(defaults: defaults).lensPlacement = .orbit
        let backup = SettingsBackup(defaults: defaults, domain: name, historyFolder: folder)
        let file = try backup.export(launchAtLogin: false)
        MagicMouseZoom(defaults: defaults).lensPlacement = .quadrants
        try backup.restore(from: file)
        #expect(MagicMouseZoom(defaults: defaults).lensPlacement == .orbit)
    }
}
