import SwiftUI

/// Preferences › Speed: mouse acceleration and speed, beyond what System Settings offers.
struct TrackingPreferences: View {
    @Bindable var tracking: PointerTracking
    @State private var showsSpeedNote = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $tracking.accelerationOff) {
                    Text("Disable pointer acceleration")
                    Text("The pointer moves the same distance however fast you move the mouse.")
                }
                .featureSpot("clip-acceleration-off")
                NumberSlider(title: tracking.accelerationOff ? "Tracking speed" : "Pointer acceleration",
                             range: MouseTracking.accelerationRange, fractionDigits: 1,
                             value: $tracking.acceleration, defaultValue: tracking.defaultAcceleration,
                             reset: tracking.resetAcceleration, spot: "clip-acceleration")
                if !tracking.accelerationOff {
                    NumberSlider(title: "Pointer speed", range: MouseTracking.speedRange, fractionDigits: 3,
                                 value: $tracking.speed, defaultValue: MouseTracking.defaultSpeed,
                                 reset: tracking.resetSpeed, spot: "clip-speed") {
                        if !tracking.miceIgnoringSpeed.isEmpty { speedWarning }
                    }
                }
            } header: {
                Text("Mouse")
            } footer: {
                Text(footer).appFont(.caption).foregroundStyle(.secondary)
            }
            .featureSpot("tracking")
            .disabled(!tracking.isAvailable)
        }
        .formStyle(.grouped)
        .onAppear { tracking.readSystem() }
    }

    private var footer: String {
        if !tracking.isAvailable { return String(localized: "This version of macOS doesn't let apps change mouse tracking.") }
        if !tracking.hasMouse { return String(localized: "Connect a mouse to change its tracking. Trackpads keep their own settings.") }
        return String(localized: "Acceleration makes fast movements go further. Applies to every mouse, and again whenever one connects. Trackpads keep their own settings.")
    }

    private var speedWarning: some View {
        Button { showsSpeedNote.toggle() } label: {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speed not supported")
        .popover(isPresented: $showsSpeedNote, arrowEdge: .top) {
            Text("\(tracking.miceIgnoringSpeed.formatted()) kept its own speed. macOS doesn't let apps change the speed of some mice, like Apple's Magic Mouse; acceleration still works.")
                .fixedSize(horizontal: false, vertical: true)
                .padding()
                .frame(width: 280, alignment: .leading)
        }
    }
}

/// A slider with its range under the title, a field to type an exact value, and a button back to the default.
private struct NumberSlider<Accessory: View>: View {
    let title: LocalizedStringKey
    let range: ClosedRange<Double>
    let fractionDigits: Int
    @Binding var value: Double
    let defaultValue: Double
    let reset: () -> Void
    var spot: String?
    @ViewBuilder var accessory: () -> Accessory

    init(title: LocalizedStringKey, range: ClosedRange<Double>, fractionDigits: Int, value: Binding<Double>,
         defaultValue: Double, reset: @escaping () -> Void, spot: String? = nil,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.range = range
        self.fractionDigits = fractionDigits
        _value = value
        self.defaultValue = defaultValue
        self.reset = reset
        self.spot = spot
        self.accessory = accessory
    }

    var body: some View {
        LabeledContent {
            HStack {
                Slider(value: $value, in: range).featureSpot(spot ?? "")
                TextField("", value: Binding(get: { value }, set: { value = $0.clamped(to: range) }),
                          format: .number.precision(.fractionLength(0...fractionDigits)))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                Button(action: reset) { Image(systemName: "arrow.counterclockwise") }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Reset to the default, \(defaultValue.formatted(.number.precision(.fractionLength(0...fractionDigits))))"))
                    .accessibilityLabel("Reset to default")
                    .disabled(abs(value - defaultValue) < 0.0005)
            }
            .frame(width: 310)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                accessory()
            }
            Text(verbatim: "(\(range.lowerBound.formatted())–\(range.upperBound.formatted()))")
        }
    }
}
