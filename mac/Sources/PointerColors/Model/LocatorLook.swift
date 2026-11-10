import CoreGraphics
import Foundation
import SwiftUI

/// How the pointer locator's ring looks and moves: it starts wide around the pointer, closes in
/// on it with an ease-out, and fades over the last quarter. Shared by the real ring and its
/// Preferences preview, so both draw the same thing.
struct LocatorLook: Equatable {
    /// Seconds the ring takes to close in.
    var duration = Self.defaultDuration
    /// The ring's radius when it appears, in points.
    var startRadius = Self.defaultStartRadius
    /// How large the ring ends, as a share of its usual end size for the pointer's size.
    var endSize = 1.0
    /// How thick both rings are, as a share of their usual 7 pt outline and 3 pt fill.
    var lineWidth = 1.0

    static let defaultDuration = 0.8
    static let defaultStartRadius = 90.0
    static let durationRange = 0.4...2.0
    static let startRadiusRange = 50.0...150.0
    static let endSizeRange = 0.5...2.0
    static let lineWidthRange = 0.5...2.0

    /// The ease-out the ring closes with, as Core Animation's control points.
    static let closingCurve = (CGPoint(x: 0.33, y: 1), CGPoint(x: 0.68, y: 1))
    /// The share of the animation after which the ring starts to fade.
    static let fadeStart = 0.75

    var outlineWidth: CGFloat { 7 * lineWidth }
    var fillWidth: CGFloat { 3 * lineWidth }

    /// Where the ring stops: around the pointer, larger for a larger pointer.
    func endRadius(pointerScale: Double) -> CGFloat {
        (18 + 8 * pointerScale) * endSize
    }

    /// Where the ring starts. With Reduce Motion it doesn't move, so it starts where it ends.
    func startRadius(pointerScale: Double, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? endRadius(pointerScale: pointerScale) : startRadius
    }

    /// The side of a square that holds the widest ring and its outline, with a little room.
    func side(pointerScale: Double) -> CGFloat {
        let widest = max(startRadius, endRadius(pointerScale: pointerScale))
        return ((widest + outlineWidth / 2) * 2).rounded(.up) + 4
    }

    /// The ring's radius a share `progress` (0–1) of the way through.
    func radius(at progress: Double, pointerScale: Double, reduceMotion: Bool) -> CGFloat {
        let start = startRadius(pointerScale: pointerScale, reduceMotion: reduceMotion)
        let end = endRadius(pointerScale: pointerScale)
        let (first, second) = Self.closingCurve
        let curve = UnitCurve.bezier(startControlPoint: UnitPoint(x: first.x, y: first.y),
                                     endControlPoint: UnitPoint(x: second.x, y: second.y))
        return start + (end - start) * curve.value(at: progress.clamped(to: 0...1))
    }

    /// The ring's opacity a share `progress` (0–1) of the way through: solid, then fading out.
    static func opacity(at progress: Double) -> Double {
        guard progress > fadeStart else { return 1 }
        return max(0, (1 - progress) / (1 - fadeStart))
    }
}
