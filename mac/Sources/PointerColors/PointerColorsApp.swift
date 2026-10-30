import SwiftUI

@main
struct PointerColorsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(get: { model.menuBarVisibility == .always },
                                         set: { model.menuBarVisibility = $0 ? .always : .never })) {
            MenuContentView(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: model.menuBarPair, colored: model.iconInPairColors))
            if let battery = model.menuBarBattery { Text("\(battery)%") }
        }
        .menuBarExtraStyle(.window)

        // A plain window rather than a Settings scene: SwiftUI keeps a Settings window at a fixed
        // size, and this one should be resizable in height.
        Window(String(localized: "Preferences"), id: PreferencesView.windowID) {
            PreferencesView(model: model)
        }
        .windowResizability(.contentMinSize)
    }
}
