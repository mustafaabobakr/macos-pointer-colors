import Carbon.HIToolbox
import Foundation

/// Registers system-wide hotkeys with Carbon. Works while other apps are in front and needs no
/// permission, unlike a global key-event monitor (which needs Accessibility or Input Monitoring).
final class HotKeyCenter {
    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private static let signature: OSType = 0x50434C52 // "PCLR"

    init() {
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    /// Replaces every registration. Returns the ids whose combo another app already owns.
    @discardableResult
    func register(_ bindings: [(id: UInt32, combo: KeyCombo, action: () -> Void)]) -> [UInt32] {
        unregisterAll()
        var failed: [UInt32] = []
        for binding in bindings {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: binding.id)
            let status = RegisterEventHotKey(binding.combo.keyCode, binding.combo.carbonModifiers,
                                             hotKeyID, GetApplicationEventTarget(), 0, &ref)
            guard status == noErr, let ref else { failed.append(binding.id); continue }
            refs[binding.id] = ref
            handlers[binding.id] = binding.action
        }
        return failed
    }

    func unregisterAll() {
        refs.values.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        handlers.removeAll()
    }

    fileprivate func handle(id: UInt32) {
        handlers[id]?()
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, context, &eventHandler)
    }
}

private func hotKeyCallback(_: EventHandlerCallRef?, _ event: EventRef?, _ context: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let context else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    let center = Unmanaged<HotKeyCenter>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async { center.handle(id: hotKeyID.id) }
    return noErr
}
