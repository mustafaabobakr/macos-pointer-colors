import SwiftUI

@main
struct PointerColorsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(model: model)
        } label: {
            Image(nsImage: MenuBarIcon.image(for: model.menuBarPair, colored: model.iconInPairColors))
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView(model: model)
        }
    }
}
