import Foundation

/// What a mouse's measured drops say about where its battery goes: how fast it drains in use and
/// how fast sitting idle, how long a charge lasts the way it's used, and what would help.
///
/// Each drop of 1% took some hours in use and some idle. Fitting every measured drop at once
/// (least squares, `drop = inUse × a + idle × b`) gives how the two rates compare; both are then
/// scaled so together they explain every percent that drained, since levels come in whole
/// percents and the fit alone runs low.
struct DrainReport: Equatable {
    /// Fewer measured drops than this swing too much to say anything.
    static let minimumSteps = 10
    /// Whole days the use in an average day is taken over, unless set otherwise.
    static let useDays = 7

    /// Measured drops it's worked out from.
    let steps: Int
    /// Percent drained per hour in use, and per hour idle.
    let inUsePerHour: Double
    let idlePerHour: Double
    /// Hours in use in an average day, as recorded.
    let useHoursPerDay: Double
    /// Seconds in use, and idle, over all the measured drops.
    let totalInUse: TimeInterval
    let totalIdle: TimeInterval

    /// Percent drained in an average day.
    var perDay: Double { inUsePerHour * useHoursPerDay + idlePerHour * (24 - useHoursPerDay) }
    var fullChargeDays: Double? { perDay > 0 ? 100 / perDay : nil }
    /// Percent a whole day idle takes.
    var idlePerDay: Double { idlePerHour * 24 }
    /// The part of an average day's drain that's idle, 0 to 1.
    var idleShare: Double { perDay > 0 ? idlePerHour * (24 - useHoursPerDay) / perDay : 0 }

    /// Nil until there are enough measured drops, and while they can't tell the two rates apart.
    /// `useHoursPerDay` is the hours in use in an average day; without it, it's taken from the
    /// time the drops cover.
    init?(steps all: [DrainStep], useHoursPerDay hours: Double? = nil) {
        let steps = Self.measured(all)
        guard steps.count >= Self.minimumSteps else { return nil }
        let use = steps.map { $0.inUse / 3_600 }, idle = steps.map { $0.idle / 3_600 }
        let drop = steps.map { Double($0.drop) }
        guard let rates = Self.fit(drop: drop, use: use, idle: idle) else { return nil }
        let explained = rates.use * use.reduce(0, +) + rates.idle * idle.reduce(0, +)
        let scale = drop.reduce(0, +) / explained
        self.steps = steps.count
        inUsePerHour = rates.use * scale
        idlePerHour = rates.idle * scale
        useHoursPerDay = hours ?? 24 * use.reduce(0, +) / (use.reduce(0, +) + idle.reduce(0, +))
        totalInUse = use.reduce(0, +) * 3_600
        totalIdle = idle.reduce(0, +) * 3_600
    }

    /// Finished drops whose time in use was recorded.
    static func measured(_ steps: [DrainStep]) -> [DrainStep] {
        steps.filter { !$0.isOngoing && $0.inUseSeconds != nil && $0.drop > 0 && $0.duration > 0 }
    }

    /// The tips that apply: idle drain over `idleShare` of a day's, or charges lasting more than
    /// `wearShare` less than they used to.
    func tips(idleShare limit: Double, trend: Double?, wearShare: Double) -> [DrainTip] {
        var tips: [DrainTip] = []
        if idleShare > limit { tips.append(.idle(share: idleShare)) }
        if let trend, trend < -wearShare { tips.append(.wear(trend: trend)) }
        return tips
    }

    /// The two rates, from the normal equations. An idle rate below zero is noise: it's taken as
    /// none, and the drops are put down to use alone.
    private static func fit(drop: [Double], use: [Double], idle: [Double]) -> (use: Double, idle: Double)? {
        let uu = dot(use, use), ii = dot(idle, idle), ui = dot(use, idle)
        let du = dot(drop, use), di = dot(drop, idle)
        let det = uu * ii - ui * ui
        guard det > 0 else { return nil }
        let a = (du * ii - di * ui) / det, b = (di * uu - du * ui) / det
        if b < 0 { return uu > 0 ? (du / uu, 0) : nil }
        return a > 0 ? (a, b) : nil
    }

    private static func dot(_ x: [Double], _ y: [Double]) -> Double { zip(x, y).reduce(0) { $0 + $1.0 * $1.1 } }
}

/// Something the report suggests.
enum DrainTip: Equatable {
    /// Idle drain is this share of a day's: switching the mouse off when away saves it.
    case idle(share: Double)
    /// Charges last this much less than the first ones.
    case wear(trend: Double)
}

/// When the turn-it-off tip shows: once idle drain passes this share of a day's.
enum IdleTipThreshold: String, CaseIterable, Identifiable {
    case above15, above25, above40

    var id: String { rawValue }
    var share: Double { [.above15: 0.15, .above25: 0.25, .above40: 0.40][self] ?? 0.25 }
    var title: String { String(localized: "Over \(Int(share * 100))% of the drain") }
}

extension MouseHistory {
    /// Every charge's drops, oldest first.
    var allSteps: [DrainStep] { charges.flatMap(\.steps) }
    /// The report as of last midnight, so it changes once a day rather than with every drop.
    func drainReport(useDays: Int = DrainReport.useDays) -> DrainReport? {
        drainReport(asOf: Calendar.current.startOfDay(for: .now), useDays: useDays)
    }

    /// The report from the drops finished by `midnight`, with the use a day from the `useDays`
    /// whole days before it.
    func drainReport(asOf midnight: Date, useDays: Int = DrainReport.useDays, calendar: Calendar = .current) -> DrainReport? {
        DrainReport(steps: allSteps.filter { $0.end <= midnight },
                    useHoursPerDay: useHoursPerDay(before: midnight, days: useDays, calendar: calendar))
    }

    /// Hours in use in an average day, over the `days` whole days before `midnight`; nil when
    /// none of them has time recorded.
    func useHoursPerDay(before midnight: Date, days count: Int = DrainReport.useDays, calendar: Calendar = .current) -> Double? {
        guard let first = calendar.date(byAdding: .day, value: -count, to: midnight) else { return nil }
        let days = charges.flatMap { $0.daily(calendar: calendar) }.filter { $0.day >= first && $0.day < midnight }
        let inUse = days.reduce(0) { $0 + $1.inUse }, recorded = days.reduce(0) { $0 + $1.inUse + $1.idle }
        return recorded > 0 ? 24 * inUse / recorded : nil
    }
}
