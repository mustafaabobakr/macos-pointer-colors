import SwiftUI

/// A setting's way back to its default: whether it has moved from it, and how to put it back.
/// A row shows a reset button after its label while `isChanged` is true.
struct SettingsReset {
    let isChanged: Bool
    let reset: () -> Void
}

private struct SettingsResetKey: EnvironmentKey {
    static let defaultValue: SettingsReset? = nil
}

extension EnvironmentValues {
    /// The reset of the setting the row inside is for.
    var settingsReset: SettingsReset? {
        get { self[SettingsResetKey.self] }
        set { self[SettingsResetKey.self] = newValue }
    }
}

extension View {
    /// Gives the setting row inside a reset button after its label, shown while `value` differs
    /// from `defaultValue`, putting the default back when clicked.
    func resettable<Value: Equatable>(_ value: Binding<Value>, to defaultValue: Value) -> some View {
        environment(\.settingsReset, SettingsReset(isChanged: value.wrappedValue != defaultValue) {
            value.wrappedValue = defaultValue
        })
    }
}

/// The small reset button after a changed setting's label. Its tooltip names the setting.
struct SettingsResetButton: View {
    let reset: SettingsReset
    /// The setting's label, for the tooltip and VoiceOver.
    let title: Text
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: reset.reset) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 13 * scale))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(Text("Reset “\(title)” to its default"))
        .accessibilityLabel(Text("Reset “\(title)” to its default"))
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }
}

/// An empty set of preferences, for building a settings model as it starts out, to read each
/// setting's default from.
enum FactoryDefaults {
    /// Empty preferences of their own for each model, `name` telling them apart.
    static func make(_ name: String) -> UserDefaults {
        let suite = "PointerColors.factoryDefaults.\(name)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

// Each settings model as it starts out, to read its settings' defaults from. Only models whose
// setup has no side effects get one (zoom, tracking, buttons, hover focus and the locator start
// monitors or read the system); the others keep their defaults as named constants.
extension PointerHighlight {
    static let factory = PointerHighlight(defaults: FactoryDefaults.make("highlight"))
}

extension BatterySettings {
    static let factory = BatterySettings(defaults: FactoryDefaults.make("battery"))
}

extension AppSettings {
    @MainActor static let factory = AppSettings(defaults: FactoryDefaults.make("app"))
}
