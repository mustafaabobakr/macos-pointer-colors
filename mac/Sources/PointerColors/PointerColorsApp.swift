import SwiftUI

@main
struct PointerColorsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        // Not MenuBarExtra(isInserted:): with it, closing the menu by clicking the icon quits the
        // app. MenuBarItem hides the icon instead.
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: model.menuBarPair, colored: model.iconInPairColors))
            if let battery = model.menuBarBattery { Text("\(battery)%") }
        }
        .menuBarExtraStyle(.window)
        // Preferences isn't a scene: PreferencesWindow keeps one window for every way in. A
        // Settings scene would also stay at one size, and this window resizes.
    }
}
