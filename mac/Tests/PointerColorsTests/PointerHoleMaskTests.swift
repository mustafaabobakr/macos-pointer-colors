import XCTest
@testable import PointerColors

/// The mask that keeps the pixel under the pointer clear, so screenshot apps skip the overlay.
@MainActor
final class PointerHoleMaskTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 0, width: 100, height: 80)

    /// Area covered by the pieces, which must not overlap.
    private func area(_ rects: [CGRect]) -> Double { rects.map { $0.width * $0.height }.reduce(0, +) }

    func testPiecesCoverEverythingButTheHole() {
        let hole = CGRect(x: 40, y: 30, width: 2, height: 2)
        let pieces = PointerHoleMask.pieces(of: bounds, around: hole)
        XCTAssertEqual(area(pieces), 100 * 80 - 4, accuracy: 0.001)
        XCTAssertFalse(pieces.contains { $0.intersects(hole) })
        XCTAssertTrue(pieces.contains { $0.contains(CGPoint(x: 10, y: 10)) })
    }

    func testNoHoleCoversEverything() {
        XCTAssertEqual(PointerHoleMask.pieces(of: bounds, around: .null).first, bounds)
        let away = CGRect(x: 500, y: 500, width: 2, height: 2)
        XCTAssertEqual(PointerHoleMask.pieces(of: bounds, around: away).first, bounds)
    }

    func testHoleAtTheEdgeLeavesNoNegativePieces() {
        let hole = CGRect(x: -1, y: -1, width: 2, height: 2)
        let pieces = PointerHoleMask.pieces(of: bounds, around: hole)
        XCTAssertTrue(pieces.allSatisfy { $0.width >= 0 && $0.height >= 0 })
        XCTAssertFalse(pieces.contains { $0.contains(CGPoint(x: 0.5, y: 0.5)) })
        XCTAssertTrue(pieces.contains { $0.contains(CGPoint(x: 50, y: 50)) })
    }

    func testPlaceUsesTheViewsOwnCoordinates() {
        let mask = PointerHoleMask()
        let shifted = CGRect(x: 10, y: 20, width: 100, height: 80)
        mask.place(hole: CGPoint(x: 50, y: 60), in: shifted)
        XCTAssertEqual(mask.frame, shifted)
        let frames = mask.sublayers?.map(\.frame) ?? []
        XCTAssertEqual(frames.count, 4)
        // The hole is at (40, 40) in the mask's own coordinates.
        XCTAssertFalse(frames.contains { $0.contains(CGPoint(x: 40, y: 40)) })
        XCTAssertTrue(frames.contains { $0.contains(CGPoint(x: 45, y: 40)) })
    }
}
