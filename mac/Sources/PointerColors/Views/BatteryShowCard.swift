import SwiftUI

/// Where the battery level shows: next to the menu-bar icon, on the Dock icon and under the
/// pointer, each always or only when low, with the level that counts as low and the side of the
/// pointer the label sits on.
struct BatteryShowCard: View {
    @Bindable var model: AppModel
    @Bindable var battery: BatterySettings

    var body: some View {
        SettingsCard("Show the level", anchor: "battery.show") {
            SettingsMenu(title: Text("Next to the menu-bar icon"), symbol: "menubar.rectangle",
                         caption: model.menuBarVisibility == .never ? Text("The menu-bar icon is hidden in General.") : nil,
                         selection: $model.batteryDisplay.revealing()) { options }
                .disabled(model.menuBarVisibility == .never)
                .featureSpot("clip-battery")
            SettingsMenu(title: Text("On the Dock icon"), symbol: "dock.rectangle",
                         caption: model.showsInDock ? nil : Text("Turn on Show in Dock in General to see it."),
                         selection: $model.dockBattery.revealing()) { options }
                .disabled(!model.showsInDock)
                .featureSpot("clip-dock-battery")
            SettingsMenu(title: Text("Under the pointer"), symbol: "cursorarrow",
                         caption: Text("A small label that follows the pointer."),
                         selection: $model.pointerBattery.revealing()) { options }
                .featureSpot("clip-pointer-battery")
            Reveal(isShown: model.pointerBattery != .off) { labelRows }
            Reveal(isShown: usesLowLevel) {
                ValueSlider(title: String(localized: "When low means below"), symbol: "battery.25percent",
                            value: $battery.lowLevel, range: BatterySettings.levelRange, format: "%.0f%%",
                            ends: .level)
            }
        }
    }

    private var options: some View {
        ForEach(BatteryDisplay.allCases) { Text($0.title).tag($0) }
    }

    /// The label's side of the pointer, over a picture of it at real size.
    @ViewBuilder private var labelRows: some View {
        let level = model.tracking.batteryLevel
        BatteryLabelPreview(position: battery.labelPosition, level: level ?? 15,
                            charging: level != nil && model.tracking.batteryCharging, redLevel: battery.redLevel,
                            pair: model.menuBarPair, pointerScale: model.scale,
                            isOn: model.pointerBattery.shows(level ?? 0, low: Int(battery.lowLevel)))
        SettingsMenu(title: Text("Label position"), symbol: "arrow.down.right.square",
                     caption: Text("At a display's edge it moves to the other side. It turns red below the alert level."),
                     selection: $battery.labelPosition) {
            ForEach(BatteryLabelPosition.allCases) { Text($0.title).tag($0) }
        }
    }

    private var usesLowLevel: Bool {
        [model.batteryDisplay, model.dockBattery, model.pointerBattery].contains(.whenLow)
    }
}
