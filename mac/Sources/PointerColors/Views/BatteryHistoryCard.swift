import SwiftUI

/// How long each mouse's charges last and how fast they drain, to see its battery wearing out.
struct BatteryHistoryCard: View {
    @Bindable var model: AppModel
    @State private var isConfirmingClear = false

    var body: some View {
        SettingsCard("Battery health", anchor: "battery.health") {
            SettingsToggle("Track each charge", symbol: "chart.line.downtrend.xyaxis",
                           caption: "Remembers how long every charge lasts, for each mouse.",
                           isOn: $model.tracksBatteryHistory)
                .featureSpot("clip-battery-health")
            if model.batteryHistory.mice.isEmpty {
                Text(model.tracksBatteryHistory ? "Nothing yet: a mouse that reports its battery shows here after its first reading."
                                                : "Turn on Track each charge to start.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.batteryHistory.mice) { MouseHealthView(mouse: $0) }
            if !model.batteryHistory.mice.isEmpty {
                Button("Clear History…", role: .destructive) { isConfirmingClear = true }
                    .confirmationDialog("Clear the battery history of every mouse?", isPresented: $isConfirmingClear) {
                        Button("Clear History", role: .destructive, action: model.clearBatteryHistory)
                    } message: {
                        Text("Charges recorded so far are deleted. Tracking goes on from the next reading.")
                    }
            }
        }
        .featureSpot("battery-health")
    }
}
