import AppKit
import CoreBluetooth
import IOBluetooth
import Observation

/// Reconnects a paired Apple mouse or trackpad that has dropped its Bluetooth connection.
///
/// IOBluetooth is only touched once Bluetooth access is allowed: without access, macOS blocks
/// the first call until the user answers its prompt. `requestAccess` asks first, without blocking.
@MainActor
@Observable
final class BluetoothReconnector {
    private(set) var state: MouseReconnectState = .unknown
    @ObservationIgnored private var accessRequest: BluetoothAccessRequest?
    /// Held here until IOBluetooth calls back, so the target outlives the attempt.
    @ObservationIgnored private var waiter: ConnectionWaiter?

    /// Five seconds, in the 0.625 ms slots Bluetooth counts its page timeout in.
    private static let pageTimeout: BluetoothHCIPageTimeout = 8000

    static var isAllowed: Bool { CBManager.authorization == .allowedAlways }

    /// Reads which devices are connected, without asking for access.
    func refresh() {
        guard !state.isBusy else { return }
        guard Self.isAllowed else {
            state = CBManager.authorization == .notDetermined ? .unknown : .noAccess
            return
        }
        state = MouseReconnectState(after: Self.pairedPointers().map(Self.pointer))
    }

    /// Asks for access the first time, then opens a connection to each device that isn't connected.
    func reconnect() async {
        guard !state.isBusy else { return }
        guard await requestAccess() else { return state = .noAccess }
        let devices = Self.pairedPointers()
        for device in devices where !device.isConnected() {
            state = .reconnecting(device.nameOrAddress ?? "")
            _ = await open(device)
        }
        state = MouseReconnectState(after: devices.map(Self.pointer))
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestAccess() async -> Bool {
        guard CBManager.authorization == .notDetermined else { return Self.isAllowed }
        let request = BluetoothAccessRequest()
        accessRequest = request
        await request.wait()
        accessRequest = nil
        return Self.isAllowed
    }

    private static func pairedPointers() -> [IOBluetoothDevice] {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return paired.filter {
            ApplePointerClass.matches(major: $0.deviceClassMajor, minor: $0.deviceClassMinor, vendor: vendorID(of: $0))
        }
    }

    private static func pointer(_ device: IOBluetoothDevice) -> PairedPointer {
        PairedPointer(address: device.addressString ?? "", name: device.nameOrAddress ?? "",
                      isConnected: device.isConnected())
    }

    /// The vendor id in the device's Device ID (PnP Information, 0x1200) record, from the records
    /// macOS keeps since pairing.
    private static func vendorID(of device: IOBluetoothDevice) -> Int? {
        let records = device.services as? [IOBluetoothSDPServiceRecord] ?? []
        let pnp = records.first { $0.hasService(from: [IOBluetoothSDPUUID(uuid16: 0x1200)!]) }
        return pnp?.getAttributeDataElement(0x0201)?.getNumberValue()?.intValue
    }

    /// Opens the baseband connection; the device's HID channels follow on their own.
    private func open(_ device: IOBluetoothDevice) async -> IOReturn {
        let status = await withCheckedContinuation { continuation in
            let waiter = ConnectionWaiter(continuation)
            self.waiter = waiter
            let started = device.openConnection(waiter, withPageTimeout: Self.pageTimeout, authenticationRequired: false)
            if started != kIOReturnSuccess { waiter.finish(started) }
        }
        waiter = nil
        return status
    }
}

/// Receives IOBluetooth's `connectionComplete:status:` and resumes the waiting reconnect once.
private final class ConnectionWaiter: NSObject {
    private var continuation: CheckedContinuation<IOReturn, Never>?

    init(_ continuation: CheckedContinuation<IOReturn, Never>) {
        self.continuation = continuation
    }

    @objc func connectionComplete(_ device: IOBluetoothDevice, status: IOReturn) {
        finish(status)
    }

    func finish(_ status: IOReturn) {
        continuation?.resume(returning: status)
        continuation = nil
    }
}

/// Shows the Bluetooth prompt through a CoreBluetooth manager, whose state changes once it's answered.
private final class BluetoothAccessRequest: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var continuation: CheckedContinuation<Void, Never>?

    @MainActor func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard CBManager.authorization != .notDetermined else { return }
        continuation?.resume()
        continuation = nil
    }
}
