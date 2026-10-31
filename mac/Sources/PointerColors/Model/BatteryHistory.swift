import Foundation

/// Every charge of every mouse since tracking began: how long each lasted and how fast it drained,
/// to see a mouse's battery wearing out.
///
/// A charge runs from the last reading at its top level to its latest reading. When the level
/// climbs again by `chargeStep`, the mouse was charged: a charge that had drained is kept, and a
/// new one starts.
struct BatteryHistory: Codable, Equatable {
    var mice: [MouseHistory] = []

    /// A rise this big (in percent) means the mouse was charged, not that a reading wobbled.
    static let chargeStep = 3

    mutating func record(_ readings: [MouseBatteryReading], at date: Date) {
        for reading in readings { record(reading, at: date) }
    }

    private mutating func record(_ reading: MouseBatteryReading, at date: Date) {
        let point = BatteryPoint(date: date, level: reading.level)
        guard let index = mice.firstIndex(where: { $0.id == reading.id }) else {
            mice.append(MouseHistory(id: reading.id, name: reading.name, current: Charge(start: point, last: point)))
            return
        }
        mice[index].name = reading.name
        mice[index].record(point)
    }
}

/// One mouse's charges: the one it's on and the ones before it, oldest first.
struct MouseHistory: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var current: Charge
    var past: [Charge] = []

    mutating func record(_ point: BatteryPoint) {
        if point.level >= current.last.level + BatteryHistory.chargeStep {
            if current.used >= BatteryHistory.chargeStep { past.append(current) }
            current = Charge(start: point, last: point)
        } else if point.level >= current.start.level {
            // Still at the top: the charge starts counting once it drops.
            current = Charge(start: point, last: point)
        } else {
            current.last = point
        }
    }

    /// Charges that drained enough, and over long enough, to say how fast they drain.
    var measured: [Charge] { (past + [current]).filter(\.isMeasured) }

    /// Days a full charge (100%) lasts, on average over every measured charge.
    var averageFullDays: Double? { Charge.fullDays(of: measured) }

    /// How much shorter (below 0) or longer the last three measured charges last than the first
    /// three, as a fraction. Nil until there are six.
    var trend: Double? {
        let charges = measured
        guard charges.count >= 6, let first = Charge.fullDays(of: Array(charges.prefix(3))),
              let recent = Charge.fullDays(of: Array(charges.suffix(3))), first > 0 else { return nil }
        return recent / first - 1
    }
}

/// A charge, from its top to its latest (or, once it's over, its last) reading.
struct Charge: Codable, Equatable {
    var start: BatteryPoint
    var last: BatteryPoint

    /// Percent drained.
    var used: Int { start.level - last.level }
    var days: Double { last.date.timeIntervalSince(start.date) / 86_400 }
    /// Percent drained a day; nil before it has drained enough to tell.
    var perDay: Double? { isMeasured ? Double(used) / days : nil }

    var isMeasured: Bool { used >= BatteryHistory.chargeStep && days >= 0.25 }

    /// Days a full charge lasts at the charges' combined rate.
    static func fullDays(of charges: [Charge]) -> Double? {
        let used = charges.reduce(0) { $0 + $1.used }
        let days = charges.reduce(0) { $0 + $1.days }
        guard used > 0, days > 0 else { return nil }
        return 100 * days / Double(used)
    }
}

struct BatteryPoint: Codable, Equatable {
    let date: Date
    let level: Int
}
