import Foundation

/// Runtime bindings to Apple's private UniversalAccessCore framework.
/// Every symbol is optional: if Apple removes one, the matching feature reports itself unavailable
/// instead of crashing.
final class UniversalAccessCore {
    static let shared = UniversalAccessCore()

    private typealias GetScale = @convention(c) () -> Double
    private typealias SetScale = @convention(c) (Double) -> Void
    private typealias GetBool = @convention(c) () -> Bool
    private typealias SetBool = @convention(c) (Bool) -> Void

    private static let libraryPath = "/System/Library/PrivateFrameworks/UniversalAccess.framework/Versions/A/Frameworks/UniversalAccessCore.framework/Versions/A/UniversalAccessCore"
    private static let fallbackNotification = "UniversalAccessDomainMouseSettingsDidChangeNotification"

    private let getScale: GetScale?
    private let setScale: SetScale?
    private let getShakeToFind: GetBool?
    private let setShakeToFind: SetBool?
    private let mouseSettingsNotification: CFString

    private init() {
        let handle = dlopen(Self.libraryPath, RTLD_NOW)
        getScale = Self.symbol(handle, "UACursorGetScale").map { unsafeBitCast($0, to: GetScale.self) }
        setScale = Self.symbol(handle, "UACursorSetScale").map { unsafeBitCast($0, to: SetScale.self) }
        getShakeToFind = Self.symbol(handle, "UAFindMyCursorIsEnabled").map { unsafeBitCast($0, to: GetBool.self) }
        setShakeToFind = Self.symbol(handle, "UAFindMyCursorSetEnabled").map { unsafeBitCast($0, to: SetBool.self) }
        mouseSettingsNotification = Self.notificationName(handle)
    }

    func cursorScale() -> Double? { getScale?() }

    /// "Shake mouse pointer to locate". Nil when the private getter is unavailable.
    func shakeToFindEnabled() -> Bool? { getShakeToFind?() }

    func setShakeToFind(_ enabled: Bool) -> Bool {
        guard let setShakeToFind else { return false }
        setShakeToFind(enabled)
        return true
    }

    /// Returns false when the private setter is unavailable.
    func setCursorScale(_ scale: Double) -> Bool {
        guard let setScale else { return false }
        setScale(scale)
        return true
    }

    func postMouseSettingsChanged() {
        let name = CFNotificationName(mouseSettingsNotification)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDistributedCenter(), name, nil, nil, true)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), name, nil, nil, true)
    }

    private static func symbol(_ handle: UnsafeMutableRawPointer?, _ name: String) -> UnsafeMutableRawPointer? {
        guard let handle else { return nil }
        return dlsym(handle, name)
    }

    private static func notificationName(_ handle: UnsafeMutableRawPointer?) -> CFString {
        guard let pointer = symbol(handle, "UADomainMouseSettingsDidChangeNotification") else {
            return fallbackNotification as CFString
        }
        return pointer.assumingMemoryBound(to: CFString.self).pointee
    }
}
