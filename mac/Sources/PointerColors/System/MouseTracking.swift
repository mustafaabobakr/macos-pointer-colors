import Foundation
import IOKit
import IOKit.hid

/// Reads and changes how fast mice move the pointer: the acceleration curve and the speed, the
/// same two properties LinearMouse sets on each mouse.
///
/// Both live on each mouse's HID service, not in a preferences file: speed is the pointer
/// resolution (lower is faster) and acceleration is the mouse acceleration, both 16.16 fixed
/// point. macOS puts its own values back when a mouse reconnects, so the caller re-applies then.
/// Trackpads are left alone; they have their own acceleration in System Settings.
///
/// The full event-system client is private API (`IOHIDEventSystemClientCreate`), looked up at
/// runtime: the public simple client can't read these properties. Without it, nothing changes.
final class MouseTracking {
    static let accelerationRange = 0.0...40.0
    static let speedRange = 0.0...1.0
    /// What macOS uses for a mouse it knows nothing about.
    static let fallbackAcceleration = 0.6875
    /// Resolutions the speed slider covers, as their inverses: 1/1200 is slowest, 1/40 fastest.
    private static let inverseResolutions = 1.0 / 1200...1.0 / 40
    /// The speed macOS gives a mouse, from its usual resolution of 400.
    static let defaultSpeed = speed(fromResolution: 400)

    private static let resolutionKey = "HIDPointerResolution" as CFString
    private static let mouseAccelerationKey = "HIDMouseAcceleration"
    private static let accelerationTypeKey = "HIDPointerAccelerationType" as CFString
    private static let trackpadAcceleration = "HIDTrackpadAcceleration"
    /// 1 turns acceleration off: the pointer moves in step with the mouse, scaled by the acceleration value.
    private static let linearScalingKey = "HIDUseLinearScalingMouseAcceleration" as CFString

    /// Properties macOS writes back after a wake, a login or a change in System Settings.
    private static let watchedKeys = [mouseAccelerationKey, "HIDPointerResolution", "HIDUseLinearScalingMouseAcceleration"]

    private let client: IOHIDEventSystemClient?
    private let isReadOnly = ScreenshotRenderer.isRendering
    private var onChange: (() -> Void)?

    init() {
        typealias Create = @convention(c) (CFAllocator?) -> Unmanaged<IOHIDEventSystemClient>?
        let create = dlsym(dlopen(nil, RTLD_NOW), "IOHIDEventSystemClientCreate").map { unsafeBitCast($0, to: Create.self) }
        client = create?(kCFAllocatorDefault)?.takeRetainedValue()
    }

    var isAvailable: Bool { client != nil }

    /// Calls `handler` on the main queue whenever something else changes the acceleration or
    /// speed, as LinearMouse does, so the app's own values can go straight back on. Both functions
    /// are private API, looked up at runtime; without them nothing is watched.
    func observeChanges(_ handler: @escaping () -> Void) {
        typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, CFString?, CFTypeRef?) -> Void
        typealias Register = @convention(c) (IOHIDEventSystemClient, CFString, Callback, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
        typealias Schedule = @convention(c) (IOHIDEventSystemClient, UnsafeMutableRawPointer) -> Void
        let library = dlopen(nil, RTLD_NOW)
        guard let client, onChange == nil,
              let register = dlsym(library, "IOHIDEventSystemClientRegisterPropertyChangedCallback").map({ unsafeBitCast($0, to: Register.self) }),
              let schedule = dlsym(library, "IOHIDEventSystemClientScheduleWithDispatchQueue").map({ unsafeBitCast($0, to: Schedule.self) })
        else { return }
        onChange = handler
        let callback: Callback = { target, _, _, _ in
            guard let target else { return }
            Unmanaged<MouseTracking>.fromOpaque(target).takeUnretainedValue().onChange?()
        }
        let target = Unmanaged.passUnretained(self).toOpaque()
        for key in Self.watchedKeys { register(client, key as CFString, callback, target, nil) }
        schedule(client, Unmanaged.passUnretained(DispatchQueue.main).toOpaque())
    }

    /// True when every mouse already has these values, so writing them again would change nothing.
    func matches(acceleration: Double, speed: Double, accelerationOff: Bool) -> Bool {
        let resolution = Self.resolution(fromSpeed: speed)
        return mice.allSatisfy { mouse in
            let hasLinearScaling = IOHIDServiceClientCopyProperty(mouse, Self.linearScalingKey) != nil
            let expected = accelerationOff && !hasLinearScaling ? -1 : acceleration.clamped(to: Self.accelerationRange)
            guard let read = property(mouse, accelerationKey(of: mouse)) as? NSNumber,
                  abs(read.doubleValue / 65_536 - expected) < 0.001 else { return false }
            if hasLinearScaling, (property(mouse, Self.linearScalingKey as String) as? NSNumber)?.intValue != (accelerationOff ? 1 : 0) {
                return false
            }
            // Mice off the speed scale, like the Magic Mouse, keep their own resolution anyway.
            guard !accelerationOff, let current = self.resolution(of: mouse), Self.isOnSpeedScale(current) else { return true }
            return abs(current - resolution) <= 1
        }
    }

    /// The acceleration System Settings › Mouse › Tracking speed has set, which every mouse
    /// starts with.
    var systemAcceleration: Double {
        guard let client, let value = IOHIDEventSystemClientCopyProperty(client, Self.mouseAccelerationKey as CFString) as? NSNumber else {
            return Self.fallbackAcceleration
        }
        return value.doubleValue / 65_536
    }

    /// The first mouse's speed, 0 to 1; nil with no mouse connected or none on the speed scale.
    var currentSpeed: Double? {
        mice.compactMap { resolution(of: $0) }.first(where: Self.isOnSpeedScale).map(Self.speed(fromResolution:))
    }

    /// Mice whose resolution is off the speed scale, like Apple's Magic Mouse: macOS sets their
    /// speed some other way and ignores a new resolution.
    var miceOffSpeedScale: [String] {
        mice.filter { resolution(of: $0).map { !Self.isOnSpeedScale($0) } ?? false }.map(name(of:))
    }

    private static func isOnSpeedScale(_ resolution: Double) -> Bool {
        (1 / inverseResolutions.upperBound...1 / inverseResolutions.lowerBound).contains(resolution)
    }

    /// True when the first mouse has acceleration turned off.
    var accelerationIsOff: Bool {
        mice.lazy.compactMap { IOHIDServiceClientCopyProperty($0, Self.linearScalingKey) as? NSNumber }.first?.intValue == 1
    }

    /// True when a mouse is connected.
    var hasMouse: Bool { !mice.isEmpty }

    /// Sets both on every connected mouse. With `accelerationOff`, the pointer moves in step with
    /// the mouse and `acceleration` only scales it, as System Settings' tracking speed does, and the
    /// speed isn't written. Returns the mice that kept their own speed: some, like Apple's Magic
    /// Mouse, ignore a new resolution on recent macOS.
    @discardableResult
    func apply(acceleration: Double, speed: Double, accelerationOff: Bool = false) -> [String] {
        guard !isReadOnly else { return [] }
        let resolution = Self.resolution(fromSpeed: speed)
        var ignoredSpeed: [String] = []
        for mouse in mice {
            let hasLinearScaling = IOHIDServiceClientCopyProperty(mouse, Self.linearScalingKey) != nil
            if hasLinearScaling {
                IOHIDServiceClientSetProperty(mouse, Self.linearScalingKey, NSNumber(value: accelerationOff ? 1 : 0))
            }
            // A new resolution only takes effect once the acceleration is written after it.
            if !accelerationOff { set(mouse, Self.resolutionKey, resolution) }
            // Mice without linear scaling, like the Magic Mouse, turn acceleration off with -1.
            let value = accelerationOff && !hasLinearScaling ? -1 : acceleration.clamped(to: Self.accelerationRange)
            set(mouse, accelerationKey(of: mouse) as CFString, value)
            if !accelerationOff, let read = self.resolution(of: mouse), abs(read - resolution) > 1 {
                ignoredSpeed.append(name(of: mouse))
            }
        }
        return ignoredSpeed
    }

    /// Each connected mouse that reports its battery, with its name and level.
    func batteryReadings() -> [MouseBatteryReading] {
        let ids = Set(mice.compactMap { mouse -> String? in
            guard let vendor = property(mouse, kIOHIDVendorIDKey), let product = property(mouse, kIOHIDProductIDKey) else { return nil }
            return "\(vendor):\(product)"
        })
        return MouseBattery.readings(vendorProductIDs: ids)
    }

    // MARK: Conversions

    static func speed(fromResolution resolution: Double) -> Double {
        let inverse = 1 / max(resolution, 1)
        let fraction = (inverse - inverseResolutions.lowerBound) / (inverseResolutions.upperBound - inverseResolutions.lowerBound)
        return fraction.clamped(to: speedRange)
    }

    static func resolution(fromSpeed speed: Double) -> Double {
        let fraction = speed.clamped(to: speedRange)
        return 1 / (inverseResolutions.lowerBound + fraction * (inverseResolutions.upperBound - inverseResolutions.lowerBound))
    }

    // MARK: Services

    /// Connected mice: services that report as a mouse and don't use a trackpad's acceleration.
    private var mice: [IOHIDServiceClient] {
        guard let client, let services = IOHIDEventSystemClientCopyServices(client) as? [IOHIDServiceClient] else { return [] }
        return services.filter { service in
            IOHIDServiceClientConformsTo(service, UInt32(kHIDPage_GenericDesktop), UInt32(kHIDUsage_GD_Mouse)) != 0
                && accelerationKey(of: service) != Self.trackpadAcceleration
        }
    }

    private func accelerationKey(of service: IOHIDServiceClient) -> String {
        IOHIDServiceClientCopyProperty(service, Self.accelerationTypeKey) as? String ?? Self.mouseAccelerationKey
    }

    private func resolution(of service: IOHIDServiceClient) -> Double? {
        (IOHIDServiceClientCopyProperty(service, Self.resolutionKey) as? NSNumber).map { $0.doubleValue / 65_536 }
    }

    private func name(of service: IOHIDServiceClient) -> String {
        property(service, kIOHIDProductKey) as? String ?? String(localized: "A mouse")
    }

    private func property(_ service: IOHIDServiceClient, _ key: String) -> Any? {
        IOHIDServiceClientCopyProperty(service, key as CFString)
    }

    private func set(_ service: IOHIDServiceClient, _ key: CFString, _ value: Double) {
        IOHIDServiceClientSetProperty(service, key, NSNumber(value: Int32(value * 65_536)))
    }
}

/// One mouse's battery: who it is, so each keeps its own history, and how full it is.
struct MouseBatteryReading: Equatable {
    /// Its serial number or Bluetooth address, or its vendor and product when it reports neither.
    let id: String
    let name: String
    let level: Int
}

/// Battery levels Bluetooth devices report through Apple's device-management HID services.
enum MouseBattery {
    static func readings(vendorProductIDs: Set<String>) -> [MouseBatteryReading] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"),
                                           &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var readings: [MouseBatteryReading] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let reading = reading(of: service, matching: vendorProductIDs) { readings.append(reading) }
        }
        return readings
    }

    private static func reading(of service: io_service_t, matching ids: Set<String>) -> MouseBatteryReading? {
        func value(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        guard let vendor = value(kIOHIDVendorIDKey), let product = value(kIOHIDProductIDKey),
              ids.contains("\(vendor):\(product)"),
              let level = (value("BatteryPercent") as? NSNumber)?.intValue else { return nil }
        let id = value(kIOHIDSerialNumberKey) as? String ?? value("DeviceAddress") as? String ?? "\(vendor):\(product)"
        let name = value(kIOHIDProductKey) as? String ?? String(localized: "A mouse")
        return MouseBatteryReading(id: id, name: name, level: level)
    }
}
