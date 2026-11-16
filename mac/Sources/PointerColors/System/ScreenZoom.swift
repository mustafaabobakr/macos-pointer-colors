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
/// With `staysPut`, a whole-screen zoom stays where it zoomed in, like macOS Smart Zoom. Each display
/// has a zoom of its own (`DisplayZooms`), which stays on it while the pointer visits the others.
@MainActor
final class ScreenZoom {
    private(set) var isZoomed = false
    var amount = MagicMouseZoom.defaultAmount
    var style = ZoomStyle.wholeScreen
    /// The lens's width and height, in points.
    var lensSize = MagicMouseZoom.defaultLensSize
    var lensShape = LensShape.rectangle
    /// Where the lens sits relative to the pointer.
    var lensPlacement = LensPlacement.onPointer
    /// Which part of the display the lens magnifies, and Pointer spot's fraction for `.pointerSpot`.
    var lensView = LensView.centred
    var lensViewSpot = MagicMouseZoom.defaultLensViewSpot
    /// Where the lens grows out of and shrinks back into.
    var lensGrowth = LensGrowth.nearestEdge
    /// The lens outline's color, read each time it zooms in.
    var lensBorderColor: () -> RGBA = { MagicMouseZoom.whiteBorder }
    /// People you share your screen with see the zoom too. Off, the zoom is hidden from screen
    /// sharing and recording, and they see the screen as it is.
    var showsInScreenShare = true {
        didSet { panel?.sharingType = sharingType }
    }
    /// A whole-screen zoom stays where it zoomed in rather than following the pointer.
    var staysPut = true
    /// Holds the zoom where the pointer is now, as if the pointer stayed there, until set back.
    /// A lens, or a whole-screen zoom that follows the pointer, stops following it.
    var isHeld = false {
        didSet { heldPointer = isHeld ? NSEvent.mouseLocation : nil }
    }
    private var heldPointer: CGPoint?
    /// The pointer's last spot on this zoom's display. With the pointer on another display, a lens or
    /// a zoom that follows the pointer stops here, and follows again once the pointer is back.
    private var lastPointerHere: CGPoint?
    /// The global area the zoom covers on screen: the whole display, or the lens; nil when not zoomed.
    var shownArea: CGRect? { isZoomed ? panel?.frame : nil }
    /// Where the zoom takes the pointer to be: where it was held, or where it is.
    private var pointer: CGPoint { heldPointer ?? NSEvent.mouseLocation }
    private var sharingType: NSWindow.SharingType { showsInScreenShare ? .readOnly : .none }
    /// How the screen's picture is enlarged: the display's smoothing, or a sharp picture of our own.
    var upscaling = ZoomUpscaling.smooth {
        didSet { sharpener.reset(); if upscaling == .smooth { imageLayer.contents = latestFrame?.surface } }
    }
    /// Seconds zooming in or out takes; 0 jumps.
    var animationLength: TimeInterval {
        get { animation.length }
        set { animation.length = newValue }
    }

    private var panel: NSPanel?
    private let imageLayer = CALayer()
    private var stream: SCStream?
    private lazy var output = ZoomStreamOutput { [weak self] frame, source in self?.received(frame, from: source) }
    private let sharpener = ZoomSharpener()
    /// The capture's newest frame, and how many have come, so a sharp picture is drawn again.
    private var latestFrame: HeldFrame?
    private var frameCount = 0
    private var displayLink: CADisplayLink?
    private var screenFrame = CGRect.zero
    private var keyMonitors: [Any] = []
    private var animation = ZoomAnimation(length: MagicMouseZoom.defaultAnimationLength)
    private var lastTick: CFTimeInterval?
    /// Eases the lens to a new side of the pointer, and when it last moved.
    private var lensGlide = LensGlide()
    private var lastLensMove: CFTimeInterval?
    /// Where the pointer was when it zoomed in, in units of the display from its top left.
    private var anchor: CGPoint?
    /// The part of the display a whole-screen zoom shows now, in the same units.
    private var shownRect: CGRect?

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
        // Held from before it zoomed in: held here instead.
        if isHeld { heldPointer = mouse }
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
        lensGlide.reset()
        lastLensMove = nil
        shownRect = nil
        anchor = nil
        lastPointerHere = nil

        displayLink?.invalidate()
        displayLink = nil
        panel?.orderOut(nil)
        panel = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.contents = nil
        CATransaction.commit()
        latestFrame = nil
        sharpener.reset()
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
            // Its own from the start, so its first frames aren't taken for an older capture's.
            self.stream = stream
            try await stream.startCapture()
            // Zoomed out meanwhile, and maybe in again with a capture of its own.
            guard self.stream === stream else { try? await stream.stopCapture(); return }
            guard isZoomed else { try? await stream.stopCapture(); return finish() }
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

    /// Just under the app's overlays, so the ring, the laser and the click pulses draw over the
    /// zoom at the pointer. They're left out of the capture, so above it is the only place they show.
    static let level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)

    private func show(on screen: NSScreen) {
        screenFrame = screen.frame
        let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.sharingType = sharingType
        panel.level = Self.level
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
        // A layer of its own animates every change unless told not to: the last zoom's lens border
        // would fade out over a whole-screen zoom.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        imageLayer.contentsGravity = .resize
        imageLayer.cornerRadius = 0
        imageLayer.masksToBounds = isLens
        imageLayer.borderWidth = isLens ? 2 : 0
        let border = lensBorderColor()
        imageLayer.borderColor = CGColor(srgbRed: border.red, green: border.green, blue: border.blue, alpha: border.alpha)
        // Clear until the first frame arrives, so the screen shows through rather than black.
        imageLayer.backgroundColor = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        // The animation waits for the first frame of the capture.
        if imageLayer.contents != nil {
            animation.advance(by: lastTick.map { link.timestamp - $0 } ?? 0)
            lastTick = link.timestamp
        }
        guard isZoomed || !animation.isFinished else { return finish() }
        place()
    }

    /// Moves the lens to the pointer and shows the part of the display under it. The zoom stays on the
    /// display it zoomed in on: with the pointer on another one, it stops where the pointer left, still zoomed.
    private func place() {
        guard let panel else { return }
        if screenFrame.contains(self.pointer) { lastPointerHere = self.pointer }
        let mouse = lastPointerHere ?? ZoomGeometry.kept(self.pointer, inside: screenFrame, margin: 0)
        let pointer = CGPoint(x: (mouse.x - screenFrame.minX) / screenFrame.width,
                              y: (screenFrame.maxY - mouse.y) / screenFrame.height)
        let grown = animation.eased
        let shownAmount = 1 + (amount - 1) * grown
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if style == .lens {
            placeLens(in: panel, at: mouse, amount: shownAmount, grown: grown)
        } else {
            let focus = staysPut ? anchor ?? pointer : pointer
            let shown = ZoomGeometry.wholeScreen(pointer: focus, amount: shownAmount)
            shownRect = shown
            imageLayer.frame = CGRect(origin: .zero, size: screenFrame.size)
            showPart(shown)
        }
        CATransaction.commit()
    }

    /// The lens grows out of its starting point to where its placement puts it, its picture magnifying as it does.
    private func placeLens(in panel: NSPanel, at mouse: CGPoint, amount: Double, grown: Double) {
        // On the display, from its top left, as the placement measures it.
        let local = CGPoint(x: mouse.x - screenFrame.minX, y: screenFrame.maxY - mouse.y)
        let lens = glidedLensFrame(pointer: local, lens: lensShape.size(width: lensSize))
        var shown = lensGrowth.frame(grown, lens: lens, pointer: local)
        shown.size = CGSize(width: max(shown.width, 1), height: max(shown.height, 1))
        panel.setFrame(CGRect(x: screenFrame.minX + shown.minX, y: screenFrame.maxY - shown.maxY,
                              width: shown.width, height: shown.height), display: false)
        imageLayer.frame = CGRect(origin: .zero, size: shown.size)
        imageLayer.cornerRadius = lensShape.cornerRadius(for: shown.size)
        let area = lensView.shownArea(pointer: local, lens: shown, amount: amount, spot: lensViewSpot)
        showPart(CGRect(x: area.minX / screenFrame.width, y: area.minY / screenFrame.height,
                        width: area.width / screenFrame.width, height: area.height / screenFrame.height))
    }

    /// Where the placement puts the lens, reached by easing its offset from the pointer, so it glides
    /// to a new side yet follows the pointer at once.
    private func glidedLensFrame(pointer: CGPoint, lens: CGSize) -> CGRect {
        let target = lensPlacement.frame(pointer: pointer, lens: lens, screen: screenFrame.size)
        let now = CACurrentMediaTime()
        let offset = lensGlide.step(toward: CGVector(dx: target.minX - pointer.x, dy: target.minY - pointer.y),
                                    after: lastLensMove.map { now - $0 } ?? 0,
                                    snaps: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        lastLensMove = now
        let frame = CGRect(origin: CGPoint(x: pointer.x + offset.dx, y: pointer.y + offset.dy), size: lens)
        return lensPlacement.staysOnScreen ? LensPlacement.kept(frame, in: screenFrame.size) : frame
    }

    /// A new frame of the current capture. Smooth shows it straight away; a sharp picture is drawn from it
    /// on the next display frame.
    private func received(_ frame: HeldFrame, from source: ObjectIdentifier) {
        // A capture still stopping sends a last few frames, maybe of another display.
        guard let stream, ObjectIdentifier(stream) == source else { return }
        latestFrame = frame
        frameCount += 1
        if upscaling == .smooth { imageLayer.contents = frame.surface }
    }

    /// Shows `part` of the display (units from its top left) across the image layer.
    private func showPart(_ part: CGRect) {
        guard let sharpening = upscaling.sharpening, let surface = latestFrame?.surface else {
            imageLayer.contentsRect = ZoomGeometry.layerRect(part)
            return
        }
        let scale = panel?.backingScaleFactor ?? 1
        let size = CGSize(width: imageLayer.bounds.width * scale, height: imageLayer.bounds.height * scale)
        guard let picture = sharpener.picture(of: surface, frame: frameCount, part: part, size: size, sharpening: sharpening) else {
            imageLayer.contents = surface
            imageLayer.contentsRect = ZoomGeometry.layerRect(part)
            return
        }
        imageLayer.contents = picture
        imageLayer.contentsRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    /// Esc zooms out, in any app, when the pointer is on this zoom's display; other displays keep
    /// theirs. Seeing keys pressed in other apps needs Accessibility.
    private func watchEscape() {
        let isEscape: (NSEvent) -> Bool = { [weak self] event in
            Int(event.keyCode) == kVK_Escape && self?.screenFrame.contains(NSEvent.mouseLocation) == true
        }
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
