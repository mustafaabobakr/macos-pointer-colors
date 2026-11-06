import CoreGraphics
import Foundation

/// How wide a GoodNotes trail is at each point, from how fast the pointer is moving: thick while
/// it moves slowly, thin on a quick flick, as GoodNotes draws its laser.
struct LaserPace {
    /// Fitted to GoodNotes on a 1:1 display, edge to edge of the red line: about 14pt at a crawl,
    /// 12 at 185 pt/s, 8 at 750 and under 4 at 8000. The widest line is the part's own size.
    static func width(speed: Double) -> Double {
        max(15.4 - 3.6 * log(1 + max(speed, 0) / 100), 3.3)
    }

    /// The share of the widest line at `speed`, from about 0.2 to 1: even a flick keeps a white core.
    static func share(speed: Double) -> Double { width(speed: speed) / width(speed: 0) }

    /// Speed is measured over the latest this-much of the movement, so uneven event timing doesn't
    /// make the width jitter from point to point.
    private static let window: TimeInterval = 0.03

    private var recent: [(point: CGPoint, time: TimeInterval)] = []

    /// The share of the widest line for a point reached at `time`.
    mutating func share(at point: CGPoint, time: TimeInterval) -> Double {
        recent.append((point, time))
        while recent.count > 2, time - recent[1].time >= Self.window { recent.removeFirst() }
        return Self.share(speed: speed)
    }

    /// Distance over time across the recent points; 0 until there are two.
    private var speed: Double {
        guard let first = recent.first, let last = recent.last, last.time > first.time else { return 0 }
        let distance = zip(recent, recent.dropFirst()).reduce(0.0) { sum, step in
            sum + hypot(step.1.point.x - step.0.point.x, step.1.point.y - step.0.point.y)
        }
        return distance / (last.time - first.time)
    }
}

/// A GoodNotes trail's shape, one path per layer size. Each point's width is the average of the
/// pace's widths within `reach` points of travel on either side, so thick and thin parts blend
/// into each other without lagging behind the pointer. Points that far behind the newest one are
/// settled into fixed ribbons; only the stretch after them is redrawn as the trail grows.
final class LaserTrailShape {
    /// Matched by eye against GoodNotes on a recorded stroke: shorter left steps where thin met
    /// thick, longer spread thickness into the thin part before a slow corner.
    static let reach = 20.0

    private let sizes: [Double]
    private var points: [CGPoint] = []
    private var shares: [Double] = []
    /// Distance along the trail to each point.
    private var along: [Double] = []
    private let settled: [LaserRibbon]
    private var settledCount = 0
    private(set) var paths: [CGPath]

    init(sizes: [Double]) {
        self.sizes = sizes
        settled = sizes.map { _ in LaserRibbon() }
        paths = sizes.map { _ in CGMutablePath() }
    }

    /// A shape through all of `points` at once, as for a picture of a finished trail.
    convenience init(sizes: [Double], points: [CGPoint], shares: [Double]) {
        self.init(sizes: sizes)
        for (point, share) in zip(points, shares) { add(point, share: share) }
    }

    func add(_ point: CGPoint, share: Double) {
        let step = points.last.map { hypot(point.x - $0.x, point.y - $0.y) } ?? 0
        along.append((along.last ?? 0) + step)
        points.append(point)
        shares.append(share)
        settle()
        paths = zip(settled, tail()).map { settledRibbon, tailRibbon in
            let path = settledRibbon.path.mutableCopy() ?? CGMutablePath()
            path.addPath(tailRibbon.path)
            return path
        }
    }

    /// Adds the points whose blend can't change any more, being `reach` behind the newest.
    private func settle() {
        let newest = along.last ?? 0
        while settledCount < points.count, newest - along[settledCount] >= Self.reach {
            addPoint(settledCount, to: settled)
            settledCount += 1
        }
    }

    /// Ribbons from the last settled point, so they join it, to the newest.
    private func tail() -> [LaserRibbon] {
        let ribbons = sizes.map { _ in LaserRibbon() }
        for index in max(settledCount - 1, 0)..<points.count { addPoint(index, to: ribbons) }
        return ribbons
    }

    private func addPoint(_ index: Int, to ribbons: [LaserRibbon]) {
        let share = blended(index)
        for (ribbon, size) in zip(ribbons, sizes) { ribbon.add(points[index], width: share * size) }
    }

    /// The average of the shares within `reach` on either side, nearer ones counting more.
    private func blended(_ index: Int) -> Double {
        let reach = Self.reach
        var (total, weights) = (0.0, 0.0)
        for other in neighbours(of: index, within: reach) {
            let weight = 1 - abs(along[other] - along[index]) / (reach * 1.0001)
            (total, weights) = (total + shares[other] * weight, weights + weight)
        }
        return weights > 0 ? total / weights : shares[index]
    }

    private func neighbours(of index: Int, within reach: Double) -> ClosedRange<Int> {
        var (low, high) = (index, index)
        while low > 0, along[index] - along[low - 1] <= reach { low -= 1 }
        while high < points.count - 1, along[high + 1] - along[index] <= reach { high += 1 }
        return low...high
    }
}

/// A line whose width changes along it, built as a filled shape: a disc at each point and a
/// tapered piece joining it to the one before. Every piece winds the same way, so where they
/// overlap the fill stays solid. A class, since it grows one path in place.
final class LaserRibbon {
    let path = CGMutablePath()
    private var last: (point: CGPoint, radius: Double)?

    /// A ribbon through `points`, `widths` wide at each.
    init(points: [CGPoint] = [], widths: [Double] = []) {
        for (point, width) in zip(points, widths) { add(point, width: width) }
    }

    func add(_ point: CGPoint, width: Double) {
        let radius = max(width / 2, 0.25)
        path.addArc(center: point, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        path.closeSubpath()
        if let last { join(last.point, last.radius, point, radius) }
        last = (point, radius)
    }

    /// The four-sided piece between two discs, wound the same way as the discs.
    private func join(_ from: CGPoint, _ fromRadius: Double, _ to: CGPoint, _ toRadius: Double) {
        let length = hypot(to.x - from.x, to.y - from.y)
        guard length > 0 else { return }
        let normal = CGPoint(x: -(to.y - from.y) / length, y: (to.x - from.x) / length)
        let corners = [offset(from, normal, -fromRadius), offset(to, normal, -toRadius),
                       offset(to, normal, toRadius), offset(from, normal, fromRadius)]
        path.addLines(between: corners)
        path.closeSubpath()
    }

    private func offset(_ point: CGPoint, _ normal: CGPoint, _ distance: Double) -> CGPoint {
        CGPoint(x: point.x + normal.x * distance, y: point.y + normal.y * distance)
    }
}
