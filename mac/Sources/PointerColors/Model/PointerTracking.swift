import AppKit
import IOKit
import Observation

/// Mouse acceleration and speed, kept on every mouse while they're the app's own.
///
/// Off (the default), the app leaves mice alone and the sliders show what macOS uses. Moving a
/// slider makes them the app's: they're saved, written to every mouse, and written again whenever a
/// mouse connects or the Mac wakes, since macOS puts its own values back then.
@MainActor
@Observable
final class PointerTracking {
    /// The app sets acceleration and speed; off leaves them to macOS.
    private(set) var isCustom: Bool { didSet { defaults.set(isCustom, forKey: Key.custom) } }
    /// 0 to 40. macOS's own curve, where higher speeds up fast movements more.
    var acceleration: Double {
        didSet { defaults.set(acceleration, forKey: Key.acceleration); takeOver() }
    }
    /// 0 to 1, slowest to fastest.
    var speed: Double {
        didSet { defaults.set(speed, forKey: Key.speed); takeOver() }
    }
    /// The pointer moves in step with the mouse, however fast it goes. `acceleration` then only
    /// scales the movement, and `speed` waits until acceleration is back on.
    var accelerationOff: Bool {
        didSet { defaults.set(accelerationOff, forKey: Key.accelerationOff); takeOver() }
    }
    /// Mice that kept their own speed the last time it was set, like Apple's Magic Mouse.
    private(set) var miceIgnoringSpeed: [String] = []
    private(set) var hasMouse = false
    /// Battery of the connected mouse that's lowest, 0 to 100; nil when none reports it.
    private(set) var batteryLevel: Int?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let mice = MouseTracking()
    @ObservationIgnored private var notifyPort: IONotificationPortRef?
    @ObservationIgnored private var batteryTimer: Timer?
    @ObservationIgnored private var isLoading = true

    var isAvailable: Bool { mice.isAvailable }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isCustom = defaults.bool(forKey: Key.custom)
        acceleration = defaults.object(forKey: Key.acceleration) as? Double ?? MouseTracking.fallbackAcceleration
        speed = defaults.object(forKey: Key.speed) as? Double ?? 0.5
        accelerationOff = defaults.bool(forKey: Key.accelerationOff)
        isLoading = false
        if isCustom { apply() } else { readSystem() }
        watchForMice()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.miceChanged() }
        }
        refreshBattery()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshBattery() }
        }
    }

    /// The acceleration System Settings › Mouse › Tracking speed has set.
    var defaultAcceleration: Double { mice.systemAcceleration }

    func resetAcceleration() { acceleration = defaultAcceleration }

    func resetSpeed() { speed = MouseTracking.defaultSpeed }

    /// Shows what macOS is using now, without taking the settings over.
    func readSystem() {
        hasMouse = mice.hasMouse
        guard !isCustom else { return }
        miceIgnoringSpeed = mice.miceOffSpeedScale
        isLoading = true
        acceleration = mice.systemAcceleration
        speed = mice.currentSpeed ?? speed
        accelerationOff = mice.accelerationIsOff
        isLoading = false
    }

    func refreshBattery() {
        batteryLevel = mice.batteryLevels().first
    }

    // MARK: Applying

    private func takeOver() {
        guard !isLoading else { return }
        isCustom = true
        apply()
    }

    private func apply() {
        miceIgnoringSpeed = mice.apply(acceleration: acceleration, speed: speed, accelerationOff: accelerationOff)
        hasMouse = mice.hasMouse
    }

    /// A mouse connected or the Mac woke: macOS has put its own values back.
    private func miceChanged() {
        if isCustom { apply() } else { readSystem() }
        refreshBattery()
    }

    /// Calls `miceChanged` a moment after any HID service appears, once macOS has set it up.
    private func watchForMice() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notifyPort = port
        IONotificationPortSetDispatchQueue(port, .main)
        var iterator: io_iterator_t = 0
        let context = Unmanaged.passUnretained(self).toOpaque()
        let result = IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOHIDEventService"),
                                                      { context, iterator in
            PointerTracking.drain(iterator)
            guard let context else { return }
            let tracking = Unmanaged<PointerTracking>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated { tracking.miceChanged() }
            }
        }, context, &iterator)
        // The notification only arms once the services already there have been read.
        if result == KERN_SUCCESS { Self.drain(iterator) }
    }

    nonisolated private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
    }

    private enum Key {
        static let custom = "trackingCustom"
        static let acceleration = "trackingAcceleration"
        static let speed = "trackingSpeed"
        static let accelerationOff = "trackingAccelerationOff"
    }
}
