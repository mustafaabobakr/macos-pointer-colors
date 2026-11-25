import AppKit
import SwiftUI

/// The mouse's battery level in a small label just under the pointer, following it.
///
/// One borderless window that ignores the mouse, on every Space and over full-screen apps. It and
/// its mouse watching exist only while a level is shown.
@MainActor
final class PointerBatteryLabel {
    private var panel: NSPanel?
    private var monitors: [Any] = []
    private var position = BatteryLabelPosition.belowRight
    /// Leads the label ahead of a moving pointer, so it doesn't trail it by a frame.
    private var lead = PointerLead()
    /// Puts the label back at the pointer itself once the moves stop.
    private var settleTimer: Timer?

    private static let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                                        .otherMouseDragged]
    /// Shows `level`, with a bolt while it's charging and red below `redLevel`, on the
    /// `position` side of the pointer, or hides the label when it's nil.
    func show(_ level: Int?, charging: Bool = false, redLevel: Int, position: BatteryLabelPosition) {
        guard let level else { return hide() }
        self.position = position
        let panel = panel ?? makePanel()
        let host = NSHostingView(rootView: BatteryLabelView(level: level, charging: charging, redLevel: redLevel))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        self.panel = panel
        follow()
        panel.orderFrontRegardless()
        startFollowing()
    }

    private func hide() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        MouseEventTap.shared.set(Self.tapID, types: Self.tapTypes, handler: nil)
        settleTimer?.invalidate()
        settleTimer = nil
        lead.reset()
        panel?.orderOut(nil)
        panel = nil
    }

    private func startFollowing() {
        guard monitors.isEmpty else { return }
        // Without the tap (no Accessibility), the monitors move it once the move reaches the app.
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { [weak self] _ in
            MainActor.assumeIsolated { self?.followWithoutTap() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.followWithoutTap() }
            return event
        }
        monitors = [global, local].compactMap { $0 }
        // With Accessibility, the tap moves the label as soon as the move happens, before any app gets it.
        MouseEventTap.shared.set(Self.tapID, types: Self.tapTypes) { [weak self] _, event in
            self?.followAhead(event)
            return .pass
        }
    }

    /// Places the label where the pointer will be when this frame reaches the screen, and sets it
    /// back at the pointer once no move has come for a little while.
    private func followAhead(_ event: CGEvent) {
        guard let point = NSEvent(cgEvent: event)?.locationInWindow else { return follow() }
        // The event's time is in nanoseconds since startup.
        follow(at: lead.predict(point, at: Double(event.timestamp) / 1_000_000_000))
        scheduleSettle()
    }

    private func scheduleSettle() {
        let fireDate = Date(timeIntervalSinceNow: Self.settleDelay)
        if let settleTimer, settleTimer.isValid { return settleTimer.fireDate = fireDate }
        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.settle() }
        }
        RunLoop.main.add(timer, forMode: .common)
        settleTimer = timer
    }

    private func settle() {
        lead.reset()
        follow()
    }

    /// No move for this long means the pointer stopped. Mice report at least every 8 ms while moving.
    private static let settleDelay = 0.015

    private func followWithoutTap() {
        guard !MouseEventTap.shared.isRunning else { return }
        follow()
    }

    private static let tapID = "batteryLabelFollow"
    private static let tapTypes: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]

    /// On the chosen side of the pointer at `location` (where it is now when nil), or the other
    /// side where that would leave its display.
    private func follow(at location: CGPoint? = nil) {
        guard let panel else { return }
        let point = location ?? NSEvent.mouseLocation
        let size = panel.frame.size
        var frame = Self.frame(at: point, size: size, position: position)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })?.frame {
            let flipsX = frame.maxX > screen.maxX || frame.minX < screen.minX
            let flipsY = frame.minY < screen.minY || frame.maxY > screen.maxY
            if flipsX || flipsY {
                frame = Self.frame(at: point, size: size, position: position.flipped(horizontally: flipsX, vertically: flipsY))
            }
        }
        panel.setFrameOrigin(frame.origin)
    }

    /// The label's frame on screen, where y grows upward, for the pointer's tip at `point`.
    private static func frame(at point: CGPoint, size: CGSize, position: BatteryLabelPosition) -> CGRect {
        let offset = position.offset(for: size)
        return CGRect(origin: CGPoint(x: point.x + offset.x, y: point.y - offset.y - size.height), size: size)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }
}
