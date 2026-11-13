import AppKit
import IOKit
import Observation
import QuartzCore

/// How many fingers rest on each Magic Mouse, frame by frame, read through Apple's private
/// MultitouchSupport framework. Every symbol is looked up at runtime: if Apple removes one,
/// `isAvailable` is false instead of the app crashing.
///
/// macOS makes new device objects when a mouse connects again, so the devices are opened afresh
/// whenever IOKit adds or removes one.
@MainActor
@Observable
final class MagicMouseTouches {
    /// A Magic Mouse is connected and being read.
    private(set) var hasMagicMouse = false
    /// Gets each frame's finger count and its time, on the system uptime clock.
    @ObservationIgnored var onFrame: ((Int, TimeInterval) -> Void)?

    /// The family Apple's multitouch driver gives a Magic Mouse. Trackpads have others.
    nonisolated static let magicMouseFamily: Int32 = 112

    @ObservationIgnored private let api = Multitouch()
    @ObservationIgnored private var devices: [UnsafeMutableRawPointer] = []
    /// Keeps the device objects alive while they're read.
    @ObservationIgnored private var deviceList: CFArray?
    @ObservationIgnored private var port: IONotificationPortRef?
    @ObservationIgnored private var iterators: [io_iterator_t] = []
    @ObservationIgnored private var isRunning = false

    /// The one being read, which the C callback hands its frames to.
    private static weak var active: MagicMouseTouches?

    var isAvailable: Bool { api != nil }

    func start() {
        guard !isRunning, api != nil else { return }
        isRunning = true
        Self.active = self
        watchDevices()
        openDevices()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        closeDevices()
        iterators.forEach { IOObjectRelease($0) }
        iterators = []
        if let port { IONotificationPortDestroy(port) }
        port = nil
    }

    // MARK: Devices

    private func openDevices() {
        guard let api else { return }
        let list = api.createList().takeRetainedValue()
        deviceList = list
        devices = (list as [AnyObject]).map { Unmanaged.passUnretained($0).toOpaque() }.filter { device in
            var family: Int32 = 0
            return api.familyID(device, &family) == 0 && family == Self.magicMouseFamily
        }
        for device in devices {
            api.register(device, Self.callback)
            _ = api.start(device, 0)
        }
        hasMagicMouse = !devices.isEmpty
    }

    private func closeDevices() {
        guard let api else { return }
        for device in devices {
            api.unregister(device, Self.callback)
            _ = api.stop(device)
        }
        devices = []
        deviceList = nil
        hasMagicMouse = false
    }

    /// Opens the devices again once IOKit has finished adding or removing one.
    private func devicesChanged() {
        guard isRunning else { return }
        closeDevices()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.isRunning, self.devices.isEmpty else { return }
            self.openDevices()
        }
    }

    private func watchDevices() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        self.port = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .commonModes)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            guard IOServiceAddMatchingNotification(port, type, IOServiceMatching("AppleMultitouchDevice"),
                                                   Self.ioCallback, context, &iterator) == KERN_SUCCESS else { continue }
            Self.drain(iterator)
            iterators.append(iterator)
        }
    }

    /// IOKit only notifies again once the iterator is read to the end.
    nonisolated private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 { IOObjectRelease(service) }
    }

    /// Runs on the main run loop, where the notification port's source is.
    private static let ioCallback: IOServiceMatchingCallback = { context, iterator in
        drain(iterator)
        guard let context else { return }
        let touches = Unmanaged<MagicMouseTouches>.fromOpaque(context).takeUnretainedValue()
        MainActor.assumeIsolated { touches.devicesChanged() }
    }

    /// Runs on the framework's own thread, so it only stamps the time and moves to the main actor.
    private static let callback: Multitouch.Callback = { _, _, fingers, _, _ in
        let count = Int(fingers)
        let time = CACurrentMediaTime()
        DispatchQueue.main.async {
            MainActor.assumeIsolated { MagicMouseTouches.active?.onFrame?(count, time) }
        }
        return 0
    }
}

/// The MultitouchSupport functions the app uses, or nil when any of them is missing.
private struct Multitouch {
    typealias Callback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    typealias CreateList = @convention(c) () -> Unmanaged<CFArray>
    typealias FamilyID = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>) -> Int32
    typealias Register = @convention(c) (UnsafeMutableRawPointer, Callback) -> Void
    typealias Start = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    typealias Stop = @convention(c) (UnsafeMutableRawPointer) -> Int32

    let createList: CreateList
    let familyID: FamilyID
    let register: Register
    let unregister: Register
    let start: Start
    let stop: Stop

    private static let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/A/MultitouchSupport"

    init?() {
        guard let handle = dlopen(Self.path, RTLD_NOW),
              let createList = dlsym(handle, "MTDeviceCreateList"),
              let familyID = dlsym(handle, "MTDeviceGetFamilyID"),
              let register = dlsym(handle, "MTRegisterContactFrameCallback"),
              let unregister = dlsym(handle, "MTUnregisterContactFrameCallback"),
              let start = dlsym(handle, "MTDeviceStart"),
              let stop = dlsym(handle, "MTDeviceStop") else { return nil }
        self.createList = unsafeBitCast(createList, to: CreateList.self)
        self.familyID = unsafeBitCast(familyID, to: FamilyID.self)
        self.register = unsafeBitCast(register, to: Register.self)
        self.unregister = unsafeBitCast(unregister, to: Register.self)
        self.start = unsafeBitCast(start, to: Start.self)
        self.stop = unsafeBitCast(stop, to: Stop.self)
    }
}
