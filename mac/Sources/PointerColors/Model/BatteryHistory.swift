import Foundation

/// Every reading of every mouse since tracking began: how long each charge lasts, how fast it
/// drains, and how long it takes to charge, to see a mouse's battery wearing out.
///
/// Each mouse keeps a log of readings. A reading is added when the level changes. While the mouse
/// charges, a single charging reading keeps the level it has reached, from when it was plugged in
/// (`date`) to the last time it was still charging (`until`). A charge runs from one charging
/// reading to the next. Each reading also counts how much of its time the mouse was in use and
/// how much it sat idle.
///
/// Older files still read: the 0.5.1 shape (each charge's top and last reading) turns into a log,
/// and a mouse or reading that can't be read is dropped rather than losing the whole file.
struct BatteryHistory: Codable, Equatable {
    /// The shape of the file: 2 adds in-use and idle time. Files without it are older.
    static let version = 2

    var mice: [MouseHistory] = []

    /// A drain this small (in percent) is a top-up or a wobble, not a charge worth keeping.
    static let chargeStep = 3

    init(mice: [MouseHistory] = []) { self.mice = mice }

    mutating func record(_ readings: [MouseBatteryReading], at date: Date, state: UsageState = .idle) {
        for reading in readings { record(reading, at: date, state: state) }
    }

    private mutating func record(_ reading: MouseBatteryReading, at date: Date, state: UsageState) {
        guard let index = mice.firstIndex(where: { $0.id == reading.id }) else {
            var mouse = MouseHistory(id: reading.id, name: reading.name, checkedAt: date)
            mouse.record(level: reading.level, charging: reading.isCharging, at: date, state: state)
            mice.append(mouse)
            return
        }
        mice[index].name = reading.name
        mice[index].record(level: reading.level, charging: reading.isCharging, at: date, state: state)
    }

    private enum CodingKeys: String, CodingKey { case version, mice }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mice = try container.decode(Lossy<MouseHistory>.self, forKey: .mice).elements
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.version, forKey: .version)
        try container.encode(mice, forKey: .mice)
    }
}

/// Whether the mouse was being used at a check: moved, clicked or scrolled in the last minute and
/// a half. (macOS counts a trackpad's pointer too; it can't tell the two apart.)
enum UsageState: String, Codable {
    case idle
    case inUse = "in-use"
}

/// One entry in a mouse's log: a level it drained to, or a time it charged.
struct BatteryReading: Codable, Equatable {
    /// When the level changed to this, or, while charging, when it was plugged in.
    let date: Date
    /// Charging readings only: the last time it was still charging.
    var until: Date?
    var level: Int
    let isCharging: Bool
    /// Whether it was in use at its latest check. Nil in files from before 0.5.2.
    var state: UsageState?
    /// Seconds of its time the mouse was in use, and sat idle, until the next reading. Nil in
    /// files from before 0.5.2.
    var inUseSeconds: TimeInterval?
    var idleSeconds: TimeInterval?

    /// A check this long after the last one means the Mac slept or the app wasn't running: only
    /// one check's worth of it can have been use.
    static let checkInterval: TimeInterval = 90

    /// Adds the time since the last check to this reading's use or idle time. A reading from
    /// before this was recorded stays unrecorded, since most of its time is already unknown.
    mutating func count(_ elapsed: TimeInterval, state: UsageState) {
        self.state = state
        guard inUseSeconds != nil || idleSeconds != nil else { return }
        let inUse = state == .inUse ? min(elapsed, Self.checkInterval) : 0
        inUseSeconds = (inUseSeconds ?? 0) + inUse
        idleSeconds = (idleSeconds ?? 0) + elapsed - inUse
    }

    /// A reading that makes sense: a level from 0 to 100, and use and idle time that aren't negative.
    var isValid: Bool { (0...100).contains(level) && (inUseSeconds ?? 0) >= 0 && (idleSeconds ?? 0) >= 0 }
}

/// One mouse's log, oldest first, and the charges worked out from it.
struct MouseHistory: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    /// The latest reading, even one that didn't change the level.
    var checkedAt: Date
    var readings: [BatteryReading] = []

    mutating func record(level: Int, charging: Bool, at date: Date, state: UsageState = .idle) {
        // The time since the last check was spent at the last reading's level.
        if !readings.isEmpty { readings[readings.count - 1].count(max(0, date.timeIntervalSince(checkedAt)), state: state) }
        checkedAt = date
        let last = readings.last
        if charging, last?.isCharging == true {
            readings[readings.count - 1].level = level
            readings[readings.count - 1].until = date
        } else if charging || last?.isCharging != false || last?.level != level {
            readings.append(BatteryReading(date: date, until: charging ? date : nil, level: level, isCharging: charging,
                                           state: state, inUseSeconds: 0, idleSeconds: 0))
        }
    }

    /// Every charge, oldest first. The last is the one it's on.
    var charges: [Charge] {
        var charges: [Charge] = []
        var charging: BatteryReading?
        var drain: [BatteryPoint] = []
        for reading in readings {
            guard reading.isCharging else {
                drain.append(BatteryPoint(date: reading.date, level: reading.level,
                                          inUseSeconds: reading.inUseSeconds, idleSeconds: reading.idleSeconds))
                continue
            }
            if let charge = Charge(charging: charging, drain: drain, end: reading.date) { charges.append(charge) }
            charging = reading
            drain = []
        }
        if let charge = Charge(charging: charging, drain: drain, end: checkedAt) { charges.append(charge) }
        return charges
    }

    /// The charge it's on.
    var current: Charge? { charges.last }

    /// Charges before this one that drained enough to count, oldest first.
    var past: [Charge] { charges.dropLast().filter { $0.used >= BatteryHistory.chargeStep } }

    /// Charges that drained enough, and over long enough, to say how fast they drain.
    var measured: [Charge] { charges.filter(\.isMeasured) }

    /// Days a full charge (100%) lasts, on average over every measured charge. Until one is
    /// measured, estimated from the charge it's on, from its top to now.
    var averageFullDays: Double? { Charge.fullDays(of: measured) ?? estimate.flatMap { Charge.fullDays(of: [$0]) } }

    /// The charge it's on, while no charge is measured yet and this one has drained at all.
    var estimate: Charge? {
        guard measured.isEmpty, let current, current.drainSoFar != nil else { return nil }
        return current
    }

    /// How much shorter (below 0) or longer the last three measured charges last than the first
    /// three, as a fraction. Nil until there are six.
    var trend: Double? {
        let charges = measured
        guard charges.count >= 6, let first = Charge.fullDays(of: Array(charges.prefix(3))),
              let recent = Charge.fullDays(of: Array(charges.suffix(3))), first > 0 else { return nil }
        return recent / first - 1
    }

    private enum CodingKeys: String, CodingKey { case id, name, checkedAt, readings, current, past }

    init(id: String, name: String, checkedAt: Date, readings: [BatteryReading] = []) {
        self.id = id
        self.name = name
        self.checkedAt = checkedAt
        self.readings = readings
    }

    /// Reads the log, or the charges a version before 0.5.2 saved, turned into a log.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        if let readings = try container.decodeIfPresent(Lossy<BatteryReading>.self, forKey: .readings) {
            self.readings = readings.elements.filter(\.isValid).sorted { $0.date < $1.date }
            checkedAt = try container.decodeIfPresent(Date.self, forKey: .checkedAt) ?? self.readings.last?.date ?? .now
            return
        }
        let current = try container.decode(LegacyCharge.self, forKey: .current)
        let past = try container.decodeIfPresent([LegacyCharge].self, forKey: .past) ?? []
        readings = LegacyCharge.readings(of: past + [current])
        checkedAt = current.last.date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(checkedAt, forKey: .checkedAt)
        try container.encode(readings, forKey: .readings)
    }
}

/// A charge, from its top to its latest (or, once it's over, its last) reading.
struct Charge: Equatable {
    /// When it was plugged in, for a charge the log saw charging.
    var pluggedIn: Date?
    /// Its top, every level it drained to, and where it stood when it ended.
    var points: [BatteryPoint]

    /// Builds the charge that starts with `charging` (nil for the log's first) and ends at `end`.
    init?(charging: BatteryReading?, drain: [BatteryPoint], end: Date) {
        var points = drain
        // macOS can stop saying it's charging before the level is read at its top: the top is
        // whichever is higher.
        // The top and the closing point mark moments, not time spent draining: no use or idle of
        // their own, in a log that records them.
        if let charging, charging.level >= drain.first?.level ?? 0 {
            let none: TimeInterval? = charging.inUseSeconds == nil ? nil : 0
            points.insert(BatteryPoint(date: charging.until ?? charging.date, level: charging.level,
                                       inUseSeconds: none, idleSeconds: none), at: 0)
        }
        guard let last = points.last else { return nil }
        let none: TimeInterval? = last.inUseSeconds == nil ? nil : 0
        points.append(BatteryPoint(date: max(end, last.date), level: last.level, inUseSeconds: none, idleSeconds: none))
        pluggedIn = charging?.date
        self.points = points
    }

    var start: BatteryPoint { points[0] }
    var last: BatteryPoint { points[points.count - 1] }

    /// Percent drained.
    var used: Int { start.level - last.level }
    var days: Double { last.date.timeIntervalSince(start.date) / 86_400 }
    /// Percent drained a day; nil before it has drained enough to tell.
    var perDay: Double? { isMeasured ? Double(used) / days : nil }
    /// Percent drained a day so far, once it has drained at all; rough until it's measured.
    var drainSoFar: Double? { used > 0 && days >= 0.25 ? Double(used) / days : nil }
    /// How long it took to charge; nil when the log didn't see it charge.
    var chargingTime: TimeInterval? {
        guard let pluggedIn, start.date > pluggedIn else { return nil }
        return start.date.timeIntervalSince(pluggedIn)
    }

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
    /// Seconds in use and idle spent at this level after `date`; nil when it wasn't recorded.
    var inUseSeconds: TimeInterval?
    var idleSeconds: TimeInterval?
}
