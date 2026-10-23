import SwiftUI

@main
struct PointerColorsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    private var model: AppModel { delegate.model }

    var body: some Scene {
        Settings {
            PreferencesView(model: model)
        }
    }
}
