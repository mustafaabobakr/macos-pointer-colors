import AppKit
import Carbon.HIToolbox
import ScreenCaptureKit

/// Pointer Colors' own zoom: a live capture of the display under the pointer, drawn magnified in
/// a window that clicks pass through. It works over every app because it never asks the app.
///
/// The zoom window and the app's other overlays, like the ring, are left out of the capture, so it
/// doesn't film itself. The app's ordinary windows, like Preferences, are filmed like any other.
/// It grows in from 1×, and shrinks back before it goes, over `animationLength` seconds.
///
/// With `staysPut`, a whole-screen zoom stays where it zoomed in, like macOS Smart Zoom, and
/// `keepInside` stops the pointer short of the display's edges.
@MainActor
final class ScreenZoom {
    private(set) var isZoomed = false
    var amount = MagicMouseZoom.defaultAmount
    var style = ZoomStyle.wholeScreen
    /// The lens's width and height, in points.
    var lensSize = MagicMouseZoom.defaultLensSize
    var lensShape = LensShape.rectangle
    /// The lens outline's color, read each time it zooms in.
    var lensBorderColor: () -> RGBA = { MagicMouseZoom.whiteBorder }
    /// People you share your screen with see the zoom too. Off, the zoom is hidden from screen
    /// sharing and recording, and they see the screen as it is.
    var showsInScreenShare = true {
        didSet { panel?.sharingType = sharingType }
    }
    /// A whole-screen zoom stays where it zoomed in rather than following the pointer.
    var staysPut = true
    private var sharingType: NSWindow.SharingType { showsInScreenShare ? .readOnly : .none }
    /// Seconds zooming in or out takes; 0 jumps.
    var animationLength: TimeInterval {
        get { animation.length }
        set { animation.length = newValue }
    }

    private var panel: NSPanel?
    private let imageLayer = CALayer()
    private var stream: SCStream?
    private lazy var output = ZoomStreamOutput { [weak self] surface in self?.imageLayer.contents = surface }
    private var displayLink: CADisplayLink?
    private var screenFrame = CGRect.zero
    private var keyMonitors: [Any] = []
    private var animation = ZoomAnimation(length: MagicMouseZoom.defaultAnimationLength)
    private var lastTick: CFTimeInterval?
    /// Where the pointer was when it zoomed in, in units of the display from its top left.
    private var anchor: CGPoint?
    /// The part of the display a whole-screen zoom shows now, in the same units.
    private var shownRect: CGRect?

    /// The display's frame in global coordinates from the top left, as mouse events give them.
    private var eventFrame = CGRect.zero

    /// Stops a pointer movement at `edgeMargin` inside the display while a zoom stays put, so the
    /// pointer never slips onto the display next to it. Moving an event moves the pointer with it.
    func keepInside(_ event: CGEvent) {
        guard isStill else { return }
        let kept = ZoomGeometry.kept(event.location, inside: eventFrame, margin: Self.edgeMargin)
        if kept != event.location { event.location = kept }
    }

    func toggle() {
        isZoomed ? zoomOut() : zoomIn()
    }

    func zoomIn() {
        guard !isZoomed else { return }
        // Still shrinking away, so grow back from where it is.
        guard panel == nil else { isZoomed = true; animation.target = 1; return }
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) else { return }
        guard ScreenRecordingAccess.isAllowed else { return ScreenRecordingAccess.request() }
        isZoomed = true
        anchor = CGPoint(x: (mouse.x - screen.frame.minX) / screen.frame.width,
                         y: (screen.frame.maxY - mouse.y) / screen.frame.height)
        Task { await startCapture(on: screen) }
    }

    /// Shrinks back to 1×, then goes. Not `animated`, it goes at once.
    func zoomOut(animated: Bool = true) {
        guard isZoomed || panel != nil else { return }
        isZoomed = false
        animation.target = 0
        guard !animated || panel == nil || animation.length == 0 else { return }
        finish()
    }

    /// Takes the window and the capture away.
    private func finish() {
        animation = ZoomAnimation(length: animation.length)
        lastTick = nil
        shownRect = nil
        anchor = nil

        displayLink?.invalidate()
        displayLink = nil
        panel?.orderOut(nil)
        panel = nil
        imageLayer.contents = nil
        keyMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors = []
        if let stream { Task { try? await stream.stopCapture() } }
        stream = nil
    }

    // MARK: Capture

    private func startCapture(on screen: NSScreen) async {
        do {
            show(on: screen)
            let stream = try await makeStream(for: screen)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: output.queue)
            try await stream.startCapture()
            guard isZoomed else { try? await stream.stopCapture(); return finish() }
            self.stream = stream
        } catch {
            zoomOut(animated: false)
        }
    }

    private func makeStream(for screen: NSScreen) async throws -> SCStream {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
            throw CocoaError(.featureUnsupported)
        }
        let pid = ProcessInfo.processInfo.processIdentifier
        // Leaving out the whole app also leaves out windows it shows later, like the zoom itself,
        // which macOS may not have listed yet. Its ordinary windows, like Preferences, sit on
        // layer 0 and are filmed like any other app's.
        let ownApp = content.applications.filter { $0.processID == pid }
        let ordinary = content.windows.filter { $0.owningApplication?.processID == pid && $0.windowLayer == 0 }
        let filter = SCContentFilter(display: display, excludingApplications: ownApp, exceptingWindows: ordinary)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
        configuration.height = Int(screen.frame.height * screen.backingScaleFactor)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.showsCursor = false
        configuration.queueDepth = 4
        return SCStream(filter: filter, configuration: configuration, delegate: nil)
    }

    // MARK: Window

    private func show(on screen: NSScreen) {
        screenFrame = screen.frame
        let top = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        eventFrame = CGRect(x: screen.frame.minX, y: top - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.sharingType = sharingType
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.wantsLayer = true
        view.layer?.addSublayer(imageLayer)

        panel.contentView = view
        styleLayer()
        animation.target = 1
        self.panel = panel
        place()
        panel.orderFrontRegardless()
        displayLink = view.displayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
        watchEscape()
    }

    private func styleLayer() {
        let isLens = style == .lens
        imageLayer.contentsGravity = .resize
        imageLayer.masksToBounds = isLens
        imageLayer.borderWidth = isLens ? 2 : 0
        let border = lensBorderColor()
        imageLayer.borderColor = CGColor(srgbRed: border.red, green: border.green, blue: border.blue, alpha: border.alpha)
        // Clear until the first frame arrives, so the screen shows through rather than black.
        imageLayer.backgroundColor = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        // A still zoom keeps the pointer in; one that follows it zooms out when it leaves.
        // A zoom that follows the pointer goes when the pointer leaves its display.
        if !isStill, !screenFrame.contains(NSEvent.mouseLocation) {
            return zoomOut(animated: false)
        }
        // The animation waits for the first frame of the capture.
        if imageLayer.contents != nil {
            animation.advance(by: lastTick.map { link.timestamp - $0 } ?? 0)
            lastTick = link.timestamp
        }
        guard isZoomed || !animation.isFinished else { return finish() }
        place()
    }

    /// Points between the pointer and the display's edges while a zoom stays put.
    static let edgeMargin: CGFloat = 10

    /// A whole-screen zoom is up and staying where it zoomed in.
    private var isStill: Bool { isZoomed && staysPut && style == .wholeScreen && panel != nil }

    /// Moves the lens to the pointer and shows the part of the display under it.
    private func place() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let pointer = CGPoint(x: (mouse.x - screenFrame.minX) / screenFrame.width,
                              y: (screenFrame.maxY - mouse.y) / screenFrame.height)
        let grown = animation.eased
        let shownAmount = 1 + (amount - 1) * grown
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if style == .lens {
            placeLens(in: panel, at: mouse, pointer: pointer, amount: shownAmount, grown: grown)
        } else {
            let focus = staysPut ? anchor ?? pointer : pointer
            let shown = ZoomGeometry.wholeScreen(pointer: focus, amount: shownAmount)
            shownRect = shown
            imageLayer.frame = CGRect(origin: .zero, size: screenFrame.size)
            imageLayer.contentsRect = ZoomGeometry.layerRect(shown)
        }
        CATransaction.commit()
    }

    /// The lens grows out of the pointer, its picture magnifying as it does.
    private func placeLens(in panel: NSPanel, at mouse: CGPoint, pointer: CGPoint, amount: Double, grown: Double) {
        let full = lensShape.size(width: lensSize)
        let window = CGRect(x: mouse.x - full.width / 2, y: mouse.y - full.height / 2, width: full.width, height: full.height)
        panel.setFrame(window, display: false)
        let size = CGSize(width: max(full.width * grown, 1), height: max(full.height * grown, 1))
        imageLayer.frame = CGRect(x: (full.width - size.width) / 2, y: (full.height - size.height) / 2,
                                  width: size.width, height: size.height)
        imageLayer.cornerRadius = lensShape.cornerRadius(for: size)
        let unit = CGSize(width: size.width / screenFrame.width, height: size.height / screenFrame.height)
        imageLayer.contentsRect = ZoomGeometry.layerRect(ZoomGeometry.lens(pointer: pointer, amount: amount, lens: unit))
    }

    /// Esc zooms out, in any app. Seeing keys pressed in other apps needs Accessibility.
    private func watchEscape() {
        let isEscape: (NSEvent) -> Bool = { Int($0.keyCode) == kVK_Escape }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            if isEscape(event) { MainActor.assumeIsolated { self?.zoomOut() } }
        }) { keyMonitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard isEscape(event) else { return event }
            self?.zoomOut()
            return nil
        }) { keyMonitors.append(local) }
    }
}
