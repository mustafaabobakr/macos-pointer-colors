import SwiftUI

/// Everything about the mouse's battery: where its level shows and when to be told it's low.
struct BatteryPreferences: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsPage("Battery") {
            SettingsCard(anchor: "battery.level") {
                SettingsRow("Your mouse", symbol: "computermouse") {
                    Label {
                        Text(levelText).monospacedDigit()
                    } icon: {
                        if model.tracking.batteryCharging {
                            Image(systemName: "bolt.fill").foregroundStyle(.green)
                        }
                    }
                }
            }
            BatteryShowCard(model: model, battery: model.battery)
            BatteryAlertCard(battery: model.battery, level: model.tracking.batteryLevel)
            BatteryHistoryCard(model: model)
        }
        .featureSpot("battery")
        .onAppear { model.tracking.refreshBattery() }
    }

    private var levelText: String {
        guard let level = model.tracking.batteryLevel else { return String(localized: "No battery reported") }
        return model.tracking.batteryCharging ? String(localized: "\(level)%, charging") : String(localized: "\(level)%")
    }
}
