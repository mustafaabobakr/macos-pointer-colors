import Foundation

/// A paired Bluetooth pointing device, as the reconnect feature sees it.
struct PairedPointer: Equatable, Identifiable {
    let address: String
    let name: String
    let isConnected: Bool

    var id: String { address }
}

/// Which paired Bluetooth devices count as an Apple mouse or trackpad.
enum ApplePointerClass {
    /// Apple's Bluetooth vendor id, read from the device's Device ID (PnP) record.
    static let appleVendor = 0x004C
    /// The Peripheral major device class.
    static let peripheralMajor: UInt32 = 0x05

    /// A peripheral whose minor class is a pointing device without a keyboard (Magic Mouse,
    /// Magic Trackpad), made by Apple.
    static func matches(major: UInt32, minor: UInt32, vendor: Int?) -> Bool {
        major == peripheralMajor && minor & 0x30 == 0x20 && vendor == appleVendor
    }
}

/// What the reconnect feature last found or is doing, shown in the menu and Preferences › General › Mouse.
enum MouseReconnectState: Equatable {
    /// Not looked yet, as before Bluetooth access is allowed.
    case unknown
    case noAccess
    case noDevice
    case connected([String])
    case reconnecting(String)
    /// The devices that didn't answer, usually because they're off or out of range.
    case failed([String])

    var isBusy: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    /// From the devices after an attempt: the ones that didn't answer, or all connected.
    init(after devices: [PairedPointer]) {
        let missing = devices.filter { !$0.isConnected }.map(\.name)
        if devices.isEmpty {
            self = .noDevice
        } else if missing.isEmpty {
            self = .connected(devices.map(\.name))
        } else {
            self = .failed(missing)
        }
    }

    var message: String {
        switch self {
        case .unknown: return String(localized: "Not checked yet")
        case .noAccess: return String(localized: "Needs Bluetooth access")
        case .noDevice: return String(localized: "No Apple mouse or trackpad is paired")
        case .connected(let names): return String(localized: "Connected: \(names.formatted(.list(type: .and)))")
        case .reconnecting(let name): return String(localized: "Reconnecting \(name)…")
        case .failed(let names): return String(localized: "Couldn't reach \(names.formatted(.list(type: .and))). Is it on?")
        }
    }
}
