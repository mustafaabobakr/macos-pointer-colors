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
        panel?.orderOut(nil)
        panel = nil
    }

    private func startFollowing() {
        guard monitors.isEmpty else { return }
        let global = NSEvent.addGlobalMonitorForEvents(matching: Self.events) { [weak self] _ in
            MainActor.assumeIsolated { self?.follow() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: Self.events) { [weak self] event in
            MainActor.assumeIsolated { self?.follow() }
            return event
        }
        monitors = [global, local].compactMap { $0 }
    }

    /// On the chosen side of the pointer, or the other side where that would leave its display.
    private func follow() {
        guard let panel else { return }
        let point = NSEvent.mouseLocation
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
