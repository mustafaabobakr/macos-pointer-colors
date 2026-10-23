import SwiftUI

@main
struct PointerColorsApp: App {
    @State private var model = AppModel()

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
