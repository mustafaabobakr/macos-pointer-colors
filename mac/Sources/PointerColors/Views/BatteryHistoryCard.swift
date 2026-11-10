import SwiftUI

/// How long each mouse's charges last and how fast they drain, to see its battery wearing out.
struct BatteryHistoryCard: View {
    @Bindable var model: AppModel
    @State private var isConfirmingClear = false

    var body: some View {
        SettingsCard("Battery health", anchor: "battery.health") {
            SettingsToggle("Track each charge", symbol: "chart.line.downtrend.xyaxis",
                           caption: "Remembers how long every charge lasts, for each mouse.",
                           isOn: $model.tracksBatteryHistory.revealing())
                .featureSpot("clip-battery-health")
            Reveal(isShown: model.tracksBatteryHistory) { reportRows }
            if model.batteryHistory.mice.isEmpty {
                Text(model.tracksBatteryHistory ? "Nothing yet: a mouse that reports its battery shows here after its first reading."
                                                : "Turn on Track each charge to start.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.batteryHistory.mice) { mouse in
                MouseHealthView(mouse: mouse, report: model.showsDrainReport ? model.idleTipThreshold : nil)
            }
            if !model.batteryHistory.mice.isEmpty {
                HStack {
                    Button("Clear History…", role: .destructive) { isConfirmingClear = true }
                        .confirmationDialog("Clear the battery history of every mouse?", isPresented: $isConfirmingClear) {
                            Button("Clear History", role: .destructive, action: model.clearBatteryHistory)
                        } message: {
                            Text("Charges recorded so far are deleted. Tracking goes on from the next reading.")
                        }
                    Spacer()
                    // The readings as saved, battery-history.json in the app's Application Support folder.
                    Button("Open History File") { NSWorkspace.shared.open(BatteryHistoryStore().fileURL) }
                        .buttonStyle(.link)
                }
            }
        }
        .featureSpot("battery-health")
        .animation(.reveal, value: model.batteryHistory.mice.count)
    }

    /// The drain report's switch and, while it's on, when it suggests switching the mouse off.
    @ViewBuilder private var reportRows: some View {
        SettingsToggle("Drain report", symbol: "lightbulb",
                       caption: "How fast it drains in use and idle, how long a charge lasts, and tips to make it last longer.",
                       isOn: $model.showsDrainReport.revealing())
        Reveal(isShown: model.showsDrainReport) {
            SettingsMenu(title: Text("Suggest switching it off"), symbol: "power",
                         caption: Text("When idle drain passes this share of a day's drain."),
                         selection: $model.idleTipThreshold) {
                ForEach(IdleTipThreshold.allCases) { Text($0.title).tag($0) }
            }
        }
    }
}
