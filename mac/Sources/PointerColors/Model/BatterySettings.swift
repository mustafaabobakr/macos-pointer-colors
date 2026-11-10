import Foundation
import Observation

/// The battery's levels, low-battery notification, pointer label and health report settings,
/// saved as they change. Percents and days are kept whole, so their sliders move freely
/// without a tick for every value: a value off a whole one is rounded and set again, which
/// saves it, since an observed property's didSet runs again for a change made inside it.
@MainActor
@Observable
final class BatterySettings {
    /// A notification when the battery drops below `alertLevel`.
    var alertsOn: Bool { didSet { save(alertsOn, Key.alertsOn); onDisplayChange?() } }
    /// Percent the battery has to fall below for the notification.
    var alertLevel: Double { didSet { guard alertLevel == alertLevel.rounded() else { return alertLevel.round() }; save(alertLevel, Key.alertLevel); onDisplayChange?() } }
    /// The notification plays the system's notification sound.
    var alertSound: Bool { didSet { save(alertSound, Key.alertSound) } }
    /// Notifies again each time the battery drops `reminderStep` percent further, until charged.
    var remindsAgain: Bool { didSet { save(remindsAgain, Key.remindsAgain) } }
    var reminderStep: Double { didSet { guard reminderStep == reminderStep.rounded() else { return reminderStep.round() }; save(reminderStep, Key.reminderStep) } }
    /// Percent below which "When low" shows the level, in the menu bar, the Dock and under the pointer.
    var lowLevel: Double { didSet { guard lowLevel == lowLevel.rounded() else { return lowLevel.round() }; save(lowLevel, Key.lowLevel); onDisplayChange?() } }
    var labelPosition: BatteryLabelPosition { didSet { save(labelPosition.rawValue, Key.labelPosition); onDisplayChange?() } }
    /// How much shorter charges have to last than the first ones for the wear tip, 0 to 1.
    var wearShare: Double { didSet { save(wearShare, Key.wearShare) } }
    /// Whole days the drain report takes the use in an average day from.
    var useDays: Double { didSet { guard useDays == useDays.rounded() else { return useDays.round() }; save(useDays, Key.useDays) } }
    /// Days the estimate chart goes back.
    var chartDays: Double { didSet { save(chartDays, Key.chartDays) } }

    /// Called when what's shown changes, to redraw the menu bar, Dock and label.
    @ObservationIgnored var onDisplayChange: (() -> Void)?

    static let levelRange = 5.0...50.0
    static let reminderStepRange = 1.0...10.0
    static let wearRange = 0.05...0.4
    static let useDaysRange = 3.0...30.0
    static let chartDaysRange = 30.0...180.0

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.alertSound: true, Key.reminderStep: 5.0, Key.wearShare: 0.15,
                                     Key.useDays: 7.0, Key.chartDays: 60.0])
        let earlierAlert = defaults.string(forKey: Key.oldAlert)
        alertsOn = defaults.object(forKey: Key.alertsOn) as? Bool ?? (Self.oldAlertLevel(earlierAlert) != nil)
        alertLevel = defaults.object(forKey: Key.alertLevel) as? Double ?? Self.oldAlertLevel(earlierAlert) ?? 10
        alertSound = defaults.bool(forKey: Key.alertSound)
        remindsAgain = defaults.bool(forKey: Key.remindsAgain)
        reminderStep = defaults.double(forKey: Key.reminderStep)
        lowLevel = defaults.object(forKey: Key.lowLevel) as? Double ?? Self.oldLowLevel(defaults)
        labelPosition = defaults.string(forKey: Key.labelPosition).flatMap(BatteryLabelPosition.init(rawValue:)) ?? .belowRight
        wearShare = defaults.double(forKey: Key.wearShare)
        useDays = defaults.double(forKey: Key.useDays)
        chartDays = defaults.double(forKey: Key.chartDays)
        // Kept from now on, so changing a show menu later doesn't move the level read from the old ones.
        save(alertsOn, Key.alertsOn)
        save(alertLevel, Key.alertLevel)
        save(lowLevel, Key.lowLevel)
    }

    /// The level the label turns red below: the alert's, so red means it's time to charge, or
    /// the low level while the alert is off.
    var redLevel: Int { Int(alertsOn ? alertLevel : lowLevel) }

    /// Earlier builds offered Off, Below 5%, Below 10% and Below 20%.
    private static func oldAlertLevel(_ raw: String?) -> Double? {
        ["below5": 5, "below10": 10, "below20": 20][raw ?? ""]
    }

    /// Earlier builds had Below 10% and Below 20% in each show menu: 10 only when no menu
    /// used 20, so nothing that showed before stops showing.
    private static func oldLowLevel(_ defaults: UserDefaults) -> Double {
        let raws = BatteryDisplay.keys.compactMap { defaults.string(forKey: $0) }
        return raws.contains("below10") && !raws.contains("below20") ? 10 : 20
    }

    private func save(_ value: Any, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private enum Key {
        static let oldAlert = "batteryAlert"
        static let alertsOn = "batteryAlertsOn"
        static let alertLevel = "batteryAlertLevel"
        static let alertSound = "batteryAlertSound"
        static let remindsAgain = "batteryRemindsAgain"
        static let reminderStep = "batteryReminderStep"
        static let lowLevel = "batteryLowLevel"
        static let labelPosition = "batteryLabelPosition"
        static let wearShare = "batteryWearShare"
        static let useDays = "batteryUseDays"
        static let chartDays = "batteryChartDays"
    }
}
