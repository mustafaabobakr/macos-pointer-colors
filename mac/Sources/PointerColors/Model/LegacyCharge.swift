import Foundation

/// A charge as versions before 0.5.2 saved it: only its top and its last reading. Still read from
/// older history files, imported backups and the feature clips' demo settings.
struct LegacyCharge: Decodable {
    let start: BatteryPoint
    let last: BatteryPoint

    /// The charges as a log: each one's top as a charging reading, and its last level.
    static func readings(of charges: [LegacyCharge]) -> [BatteryReading] {
        charges.flatMap { charge in
            let top = BatteryReading(date: charge.start.date, until: charge.start.date,
                                     level: charge.start.level, isCharging: true)
            guard charge.last.level != charge.start.level else { return [top] }
            return [top, BatteryReading(date: charge.last.date, level: charge.last.level, isCharging: false)]
        }
    }
}
