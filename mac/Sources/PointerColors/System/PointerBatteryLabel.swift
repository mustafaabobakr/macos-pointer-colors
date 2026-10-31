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

    private static let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                                        .otherMouseDragged]
    /// From the pointer's tip to the label's top left corner, clear of a large pointer.
    private static let offset = CGSize(width: 14, height: 30)

    /// Shows `level`, or hides the label when it's nil.
    func show(_ level: Int?) {
        guard let level else { return hide() }
        let panel = panel ?? makePanel()
        let host = NSHostingView(rootView: LabelView(level: level))
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

    /// Below and to the right of the pointer, or above and to the left where that would leave its display.
    private func follow() {
        guard let panel else { return }
        let point = NSEvent.mouseLocation
        let size = panel.frame.size
        var origin = CGPoint(x: point.x + Self.offset.width, y: point.y - Self.offset.height - size.height)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })?.frame {
            if origin.x + size.width > screen.maxX { origin.x = point.x - Self.offset.width - size.width }
            if origin.y < screen.minY { origin.y = point.y + Self.offset.width }
        }
        panel.setFrameOrigin(origin)
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

private struct LabelView: View {
    let level: Int

    var body: some View {
        Label("\(level)%", systemImage: symbol)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(level < 20 ? .red : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.regularMaterial, in: Capsule())
            .padding(2)
    }

    private var symbol: String {
        switch level {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
