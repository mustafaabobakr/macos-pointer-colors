import Foundation

/// One drop in level on a charge, from the reading that reached `from` to the one that reached
/// `level`. The last step is the level it's on now, still going.
struct DrainStep: Equatable {
    /// A drop of 1% that takes longer than this was mostly idle: a night, a weekend.
    static let idleLimit: TimeInterval = 6 * 3_600

    let from: Int
    let level: Int
    let start: Date
    let end: Date
    let isOngoing: Bool
    /// Seconds of it the mouse was in use, as recorded; nil for readings from before 0.5.2.
    var inUseSeconds: TimeInterval?

    var drop: Int { from - level }
    var duration: TimeInterval { end.timeIntervalSince(start) }
    /// How long each 1% of it took. The step it's on counts as 1% so far.
    var perPercent: TimeInterval { duration / Double(max(drop, 1)) }
    /// Mostly idle: under half of it in use, or, before that was recorded, over 6 hours for 1%.
    var isIdle: Bool { inUseSeconds.map { $0 < duration / 2 } ?? (perPercent > Self.idleLimit) }
    /// Seconds of it in use: as recorded, or all of it unless it was idle.
    var inUse: TimeInterval { inUseSeconds ?? (isIdle ? 0 : duration) }
    var idle: TimeInterval { max(0, duration - inUse) }
}

extension Charge {
    /// Every drop in level, oldest first, then the level it's on now. A rise (a wobble) doesn't
    /// start a step; the time runs on from the last drop.
    var steps: [DrainStep] {
        var steps: [DrainStep] = []
        var top = start
        var usage = Usage(start)
        for point in points.dropFirst() {
            guard point.level < top.level else {
                usage.add(point)
                continue
            }
            steps.append(DrainStep(from: top.level, level: point.level, start: top.date, end: point.date,
                                   isOngoing: false, inUseSeconds: usage.inUse))
            top = point
            usage = Usage(point)
        }
        steps.append(DrainStep(from: top.level, level: top.level, start: top.date, end: last.date,
                               isOngoing: true, inUseSeconds: usage.inUse))
        return steps
    }

    /// How long 1% takes while the mouse is in use: the drops that weren't idle, together. Nil
    /// until one has finished.
    var inUsePerPercent: TimeInterval? {
        let used = steps.filter { !$0.isOngoing && ($0.inUseSeconds != nil || !$0.isIdle) }
        let drop = used.reduce(0) { $0 + $1.drop }
        let time = used.reduce(0) { $0 + $1.inUse }
        guard drop > 0, time > 0 else { return nil }
        return time / Double(drop)
    }
}

/// In-use time added up over the readings of one step; nil once any of them didn't record it.
private struct Usage {
    var inUse: TimeInterval?

    init(_ point: BatteryPoint) { inUse = point.inUseSeconds }

    mutating func add(_ point: BatteryPoint) {
        guard let inUse, let more = point.inUseSeconds else { return self.inUse = nil }
        self.inUse = inUse + more
    }
}

/// One calendar day of a charge: how much it drained, and how long the mouse was in use and idle.
struct DrainDay: Equatable {
    /// Midnight starting the day, in the user's time zone.
    let day: Date
    var used = 0
    var inUse: TimeInterval = 0
    var idle: TimeInterval = 0
}

extension Charge {
    /// Each day of the charge, oldest first. A drop counts on the day it happened; a step's use
    /// and idle time is shared out over the days it spans.
    func daily(calendar: Calendar = .current) -> [DrainDay] {
        var days: [Date: DrainDay] = [:]
        for step in steps {
            if !step.isOngoing { days[calendar.startOfDay(for: step.end), default: DrainDay(day: calendar.startOfDay(for: step.end))].used += step.drop }
            for (day, share) in Self.shares(of: step, calendar: calendar) {
                days[day, default: DrainDay(day: day)].inUse += step.inUse * share
                days[day, default: DrainDay(day: day)].idle += step.idle * share
            }
        }
        return days.values.sorted { $0.day < $1.day }
    }

    /// The part of a step that falls on each day it spans.
    private static func shares(of step: DrainStep, calendar: Calendar) -> [(Date, Double)] {
        guard step.duration > 0 else { return [] }
        var shares: [(Date, Double)] = []
        var day = calendar.startOfDay(for: step.start)
        while day < step.end {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let overlap = min(next, step.end).timeIntervalSince(max(day, step.start))
            shares.append((day, overlap / step.duration))
            day = next
        }
        return shares
    }
}
