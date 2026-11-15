import CoreGraphics
import Foundation
import Testing
@testable import PointerColors

struct LensViewTests {
    let pointer = CGPoint(x: 500, y: 400)
    /// A lens up-left of the pointer, 300 × 200.
    let lens = CGRect(x: 188, y: 188, width: 300, height: 200)

    private func area(_ view: LensView, spot: Double = 0.3) -> CGRect {
        view.shownArea(pointer: pointer, lens: lens, amount: 2, spot: spot)
    }

    @Test func `centred keeps the pointer in the middle, at the zoom amount`() {
        let shown = area(.centred)
        #expect(shown.midX == 500 && shown.midY == 400)
        #expect(shown.size == CGSize(width: 150, height: 100))
    }

    @Test func `toward the lens puts the pointer near the picture's corner nearest it`() {
        let shown = area(.towardLens)
        #expect(abs((pointer.x - shown.minX) / shown.width - 0.9) < 1e-9)
        #expect(abs((pointer.y - shown.minY) / shown.height - 0.9) < 1e-9)
    }

    @Test func `toward the lens is centred when the lens is on the pointer`() {
        let onPointer = CGRect(x: 350, y: 300, width: 300, height: 200)
        let shown = LensView.towardLens.shownArea(pointer: pointer, lens: onPointer, amount: 2, spot: 0.3)
        #expect(shown.midX == 500 && shown.midY == 400)
    }

    @Test func `under the lens shows what the lens covers`() {
        let shown = area(.underLens)
        #expect(shown.midX == lens.midX && shown.midY == lens.midY)
    }

    @Test func `pointer at a spot puts the tip at that share of the picture`() {
        let shown = area(.pointerSpot, spot: 0.25)
        #expect(pointer.x - shown.minX == 0.25 * shown.width)
        #expect(pointer.y - shown.minY == 0.25 * shown.height)
    }

    @Test(arguments: LensGrowth.allCases)
    func `every growth ends at the lens's frame`(growth: LensGrowth) {
        #expect(growth.frame(1, lens: lens, pointer: pointer) == lens)
        #expect(growth.frame(0, lens: lens, pointer: pointer).size == .zero)
    }

    @Test func `each growth starts from its own point`() {
        #expect(LensGrowth.pointer.frame(0, lens: lens, pointer: pointer).origin == pointer)
        #expect(LensGrowth.lensCentre.frame(0, lens: lens, pointer: pointer).origin == CGPoint(x: lens.midX, y: lens.midY))
        #expect(LensGrowth.nearestEdge.frame(0, lens: lens, pointer: pointer).origin == CGPoint(x: lens.maxX, y: lens.maxY))
    }

    @Test func `nearest edge keeps its start point still while growing`() {
        let half = LensGrowth.nearestEdge.frame(0.5, lens: lens, pointer: pointer)
        #expect(half.maxX == lens.maxX && half.maxY == lens.maxY)
    }

    @MainActor
    @Test func `defaults, saving, clamping and backup`() throws {
        let name = "LensViewTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let zoom = MagicMouseZoom(defaults: defaults)
        #expect(zoom.lensView == .centred && zoom.lensGrowth == .nearestEdge && zoom.lensViewSpot == 0.3)
        zoom.lensView = .pointerSpot
        zoom.lensViewSpot = 0.45
        zoom.lensGrowth = .pointer
        let folder = FileManager.default.temporaryDirectory.appending(path: name)
        defer { try? FileManager.default.removeItem(at: folder) }
        let backup = SettingsBackup(defaults: defaults, domain: name, historyFolder: folder)
        let file = try backup.export(launchAtLogin: false)
        zoom.lensView = .underLens
        zoom.lensGrowth = .lensCentre
        try backup.restore(from: file)
        let restored = MagicMouseZoom(defaults: defaults)
        #expect(restored.lensView == .pointerSpot && restored.lensViewSpot == 0.45 && restored.lensGrowth == .pointer)
        defaults.set(5.0, forKey: "magicMouseZoomLensViewSpot")
        #expect(MagicMouseZoom(defaults: defaults).lensViewSpot == 0.9)
    }
}
