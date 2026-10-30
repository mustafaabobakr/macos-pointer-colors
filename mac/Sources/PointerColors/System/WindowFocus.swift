import AppKit
import Carbon

// Adapted from LinearMouse (MIT, Copyright (c) 2021-2026 LinearMouse), which adapts it from yabai
// (MIT, Copyright (c) 2019 Åsmund Vikane):
// https://github.com/linearmouse/linearmouse/blob/main/LinearMouse/WindowFocus/WindowFocus.swift

/// Finds the window under a point and gives it keyboard focus without bringing it to the front,
/// through private WindowServer calls looked up at runtime. A missing call means no focusing at all.
final class WindowFocus: @unchecked Sendable {
    static let shared = WindowFocus()

    struct Target: Equatable {
        let pid: pid_t
        let windowID: CGWindowID
    }

    private typealias FrontProcess = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>?, UInt32, UInt32) -> CGError
    private typealias PostRecord = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>?, UnsafeMutablePointer<UInt8>?) -> CGError
    private typealias WindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>?) -> AXError
    private typealias ProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>?) -> OSStatus
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias FindWindow = @convention(c) (Int32, Int32, Int32, Int32, UnsafeMutablePointer<CGPoint>?,
                                                   UnsafeMutablePointer<CGPoint>?, UnsafeMutablePointer<UInt32>?,
                                                   UnsafeMutablePointer<Int32>?) -> OSStatus
    private typealias ConnectionPID = @convention(c) (Int32, UnsafeMutablePointer<pid_t>?) -> CGError

    private let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private let process = dlopen(nil, RTLD_LAZY)
    private let setFrontProcess: FrontProcess?
    private let postRecord: PostRecord?
    private let getWindowID: WindowID?
    private let processForPID: ProcessForPID?
    private let mainConnection: MainConnection?
    private let findWindow: FindWindow?
    private let connectionPID: ConnectionPID?

    private init() {
        setFrontProcess = Self.symbol("_SLPSSetFrontProcessWithOptions", in: skyLight)
        postRecord = Self.symbol("SLPSPostEventRecordTo", in: skyLight)
        getWindowID = Self.symbol("_AXUIElementGetWindow", in: process)
        processForPID = Self.symbol("GetProcessForPID", in: process)
        mainConnection = Self.symbol("SLSMainConnectionID", in: skyLight)
        findWindow = Self.symbol("SLSFindWindowAndOwner", in: skyLight)
        connectionPID = Self.symbol("SLSConnectionGetPID", in: skyLight)
    }

    var isAvailable: Bool {
        setFrontProcess != nil && postRecord != nil && getWindowID != nil && processForPID != nil
            && mainConnection != nil && findWindow != nil && connectionPID != nil
    }

    func windowID(of window: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard let getWindowID, getWindowID(window, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// The window under `point` (global, top-left origin), whatever it is: a menu or a panel too.
    func window(at point: CGPoint) -> Target? {
        guard let mainConnection, let findWindow, let connectionPID else { return nil }
        var point = point
        var local = CGPoint.zero
        var id: UInt32 = 0
        var owner: Int32 = 0
        var pid: pid_t = 0
        guard findWindow(mainConnection(), 0, 1, 0, &point, &local, &id, &owner) == noErr,
              id != 0, owner != 0, connectionPID(owner, &pid) == .success, pid > 0 else { return nil }
        return Target(pid: pid, windowID: id)
    }

    /// Makes `target` the key window, leaving it where it is in the stack. `previous` is the
    /// window that has focus now, deactivated first when it belongs to the same app.
    func focus(_ target: Target, from previous: Target) -> Bool {
        guard let setFrontProcess, let postRecord, let processForPID, target.windowID != 0 else { return false }
        var psn = ProcessSerialNumber()
        guard processForPID(target.pid, &psn) == noErr else { return false }
        if target.pid == previous.pid, previous.windowID != 0, previous.windowID != target.windowID {
            var deactivate = Self.stateRecord(windowID: previous.windowID, state: 2)
            guard postRecord(&psn, &deactivate) == .success else { return false }
            Thread.sleep(forTimeInterval: 0.04)
            var activate = Self.stateRecord(windowID: target.windowID, state: 1)
            guard postRecord(&psn, &activate) == .success else { return false }
        }
        guard setFrontProcess(&psn, target.windowID, 0x200) == .success else { return false }
        var record = Self.keyRecord(windowID: target.windowID)
        record[8] = 1
        guard postRecord(&psn, &record) == .success else { return false }
        record[8] = 2
        return postRecord(&psn, &record) == .success
    }

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer?) -> T? {
        guard let handle, let address = dlsym(handle, name) else { return nil }
        return unsafeBitCast(address, to: T.self)
    }

    private static func baseRecord(windowID: CGWindowID) -> [UInt8] {
        var record = [UInt8](repeating: 0, count: 0xF8)
        record[4] = 0xF8
        withUnsafeBytes(of: windowID) { record.replaceSubrange(0x3C..<0x40, with: $0) }
        return record
    }

    private static func stateRecord(windowID: CGWindowID, state: UInt8) -> [UInt8] {
        var record = baseRecord(windowID: windowID)
        record[8] = 0x0D
        record[0x8A] = state
        return record
    }

    private static func keyRecord(windowID: CGWindowID) -> [UInt8] {
        var record = baseRecord(windowID: windowID)
        record[0x3A] = 0x10
        record.replaceSubrange(0x20..<0x30, with: repeatElement(UInt8(0xFF), count: 0x10))
        return record
    }
}

/// Accessibility checks on windows: only an app's ordinary windows take focus, never a menu, a
/// panel, a sheet or a minimized window.
struct WindowQuery {
    private let system = AXUIElementCreateSystemWide()

    init() {
        AXUIElementSetMessagingTimeout(system, 0.05)
    }

    func canFocus(_ target: WindowFocus.Target, at point: CGPoint) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: target.pid), app.activationPolicy == .regular,
              !app.isTerminated, !app.isHidden, isNormalWindow(target, at: point) else { return false }
        let application = AXUIElementCreateApplication(target.pid)
        AXUIElementSetMessagingTimeout(application, 0.05)
        guard let windows = value(kAXWindowsAttribute, on: application) as? [AXUIElement],
              let window = windows.first(where: { WindowFocus.shared.windowID(of: $0) == target.windowID }) else { return false }
        return isStandard(window) && (value(kAXMinimizedAttribute, on: window) as? Bool) == false
    }

    /// The window with keyboard focus now, or nil while a menu is open or focus can't be told.
    func currentFocus() -> WindowFocus.Target? {
        guard let app = element(kAXFocusedApplicationAttribute, on: system) ?? frontmostApplication() else { return nil }
        AXUIElementSetMessagingTimeout(app, 0.05)
        var pid: pid_t = 0
        guard AXUIElementGetPid(app, &pid) == .success,
              NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular,
              !isInMenu(app) else { return nil }
        guard let window = element(kAXFocusedWindowAttribute, on: app) else { return WindowFocus.Target(pid: pid, windowID: 0) }
        guard isStandard(window), let id = WindowFocus.shared.windowID(of: window) else { return nil }
        return WindowFocus.Target(pid: pid, windowID: id)
    }

    /// A normal, visible window at `point` in the on-screen list, owned by the target's process.
    private func isNormalWindow(_ target: WindowFocus.Target, at point: CGPoint) -> Bool {
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let window = windows.first(where: { $0[kCGWindowNumber as String] as? CGWindowID == target.windowID }),
              window[kCGWindowOwnerPID as String] as? pid_t == target.pid,
              window[kCGWindowLayer as String] as? Int == 0,
              (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let bounds = window[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds) else { return false }
        return rect.contains(point)
    }

    private func isStandard(_ window: AXUIElement) -> Bool {
        let children = value(kAXChildrenAttribute, on: window) as? [AXUIElement] ?? []
        return value(kAXSubroleAttribute, on: window) as? String == kAXStandardWindowSubrole
            && (value(kAXModalAttribute, on: window) as? Bool) != true
            && !children.contains { value(kAXRoleAttribute, on: $0) as? String == kAXSheetRole }
    }

    private func isInMenu(_ app: AXUIElement) -> Bool {
        if let focused = element(kAXFocusedUIElementAttribute, on: app),
           let role = value(kAXRoleAttribute, on: focused) as? String,
           [kAXMenuRole, kAXMenuItemRole, kAXMenuBarItemRole, kAXComboBoxRole].contains(role) { return true }
        let selected = element(kAXMenuBarAttribute, on: app).flatMap { value(kAXSelectedChildrenAttribute, on: $0) as? [AXUIElement] }
        return !(selected ?? []).isEmpty
    }

    /// Some Electron apps never answer which app has focus; the frontmost one stands in.
    private func frontmostApplication() -> AXUIElement? {
        NSWorkspace.shared.frontmostApplication.map { AXUIElementCreateApplication($0.processIdentifier) }
    }

    private func value(_ attribute: String, on element: AXUIElement) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success ? result : nil
    }

    private func element(_ attribute: String, on element: AXUIElement) -> AXUIElement? {
        guard let result = value(attribute, on: element), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
}
