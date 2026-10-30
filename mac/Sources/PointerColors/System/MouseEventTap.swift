import AppKit
import ApplicationServices
import Observation

/// One session event tap that features hook into to see, and drop, mouse events before apps get
/// them. Watching NSEvents can't stop an event; a tap can, and it needs Accessibility permission.
///
/// The tap exists only while some feature is on. Until Accessibility is allowed it checks every
/// two seconds, and starts the moment it is.
@MainActor
@Observable
final class MouseEventTap {
    static let shared = MouseEventTap()

    /// What a feature wants done with an event.
    enum Verdict { case pass, drop }
    typealias Handler = (CGEventType, CGEvent) -> Verdict

    /// Accessibility is allowed, so the tap can run.
    private(set) var isTrusted = AXIsProcessTrusted()
    /// The tap is watching events.
    private(set) var isRunning = false

    /// Marks events this app posts, so its own features don't handle them again.
    nonisolated static let syntheticMarker: Int64 = 0x5043_4F4C

    @ObservationIgnored private var handlers: [String: (types: [CGEventType], handle: Handler)] = [:]
    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var source: CFRunLoopSource?
    @ObservationIgnored private var trustTimer: Timer?

    private init() {}

    /// Starts handing `types` to `handler` under `id`, or stops with nil.
    func set(_ id: String, types: [CGEventType], handler: Handler?) {
        handlers[id] = handler.map { (types, $0) }
        rebuild()
    }

    /// Shows the system prompt, then opens Privacy & Security › Accessibility.
    func requestAccess() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        isTrusted = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        guard !isTrusted, let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Tap

    private func rebuild() {
        removeTap()
        guard !handlers.isEmpty, !ScreenshotRenderer.isRendering else { return stopWaitingForTrust() }
        isTrusted = AXIsProcessTrusted()
        guard isTrusted else { return waitForTrust() }
        stopWaitingForTrust()
        let mask = handlers.values.flatMap(\.types).reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: Self.callback, userInfo: context) else {
            return waitForTrust()
        }
        isRunning = true
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = tap
        self.source = source
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        isRunning = false
    }

    private func waitForTrust() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                // macOS can report the permission before a tap may be made; the notice offers a relaunch then.
                guard let self, AXIsProcessTrusted() else { return }
                self.isTrusted = true
                self.rebuild()
            }
        }
    }

    private func stopWaitingForTrust() {
        trustTimer?.invalidate()
        trustTimer = nil
    }

    /// Runs on the main run loop, where the tap's source is.
    private static let callback: CGEventTapCallBack = { _, type, event, context in
        guard let context else { return Unmanaged.passUnretained(event) }
        let tap = Unmanaged<MouseEventTap>.fromOpaque(context).takeUnretainedValue()
        return MainActor.assumeIsolated { tap.handle(type, event) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.syntheticMarker else {
            return Unmanaged.passUnretained(event)
        }
        // Every handler sees the event, so each keeps its own state right, even after one drops it.
        let verdicts = handlers.values.filter { $0.types.contains(type) }.map { $0.handle(type, event) }
        return verdicts.contains(.drop) ? nil : Unmanaged.passUnretained(event)
    }
}
