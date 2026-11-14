import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Preferences › Zoom: a Magic Mouse double tap zooms in on what's under the pointer.
struct ZoomPreferences: View {
    let zoom: MagicMouseZoom

    var body: some View {
        SettingsPage("Zoom", isBeta: PreferencesTab.zoom.isBeta) {
            AccessibilityNotice(isNeeded: zoom.needsAccessibility)
            SmartZoomSection(zoom: zoom)
            Reveal(isShown: zoom.isOn) {
                NativeZoomAppsSection(zoom: zoom)
            }
            Reveal(isShown: zoom.isOn) {
                AdvancedTapSection(zoom: zoom)
            }
        }
        .animation(.reveal, value: zoom.nativeZoomApps.map(\.id))
    }
}

/// A double tap on a Magic Mouse zooms in on whatever is under the pointer, in any app.
private struct SmartZoomSection: View {
    @Bindable var zoom: MagicMouseZoom
    /// Read again whenever the app comes forward, as the user may have just allowed it.
    @State private var canRecord = ScreenRecordingAccess.isAllowed

    var body: some View {
        SettingsCard("Smart zoom", anchor: "zoom.magicMouse") {
            SettingsToggle("Double-tap the Magic Mouse to zoom", symbol: "plus.magnifyingglass",
                           caption: "Zooms in on what's under the pointer, in any app and on any display. Double-tap again, or press Esc, to zoom back out. Tap lightly with one finger, without clicking.",
                           isOn: $zoom.isOn.revealing())
                .featureSpot("clip-zoom-on")
            Reveal(isShown: zoom.isOn && !canRecord && !ScreenshotRenderer.isRendering) {
                SettingsRow(symbol: "exclamationmark.triangle.fill", title: Text("Needs Screen Recording").foregroundStyle(.orange),
                            caption: Text("Pointer Colors draws the zoom from a live picture of the screen. Nothing is saved or sent anywhere.")) {
                    Button("Allow…", action: ScreenRecordingAccess.request)
                }
            }
            Reveal(isShown: zoom.isOn && !zoom.touches.hasMagicMouse && !ScreenshotRenderer.isRendering) {
                SettingsRow(symbol: "computermouse", title: Text("No Magic Mouse connected").foregroundStyle(.secondary),
                            caption: Text("Zoom starts working as soon as one connects.")) {
                    EmptyView()
                }
            }
            Reveal(isShown: zoom.isOn) {
                SettingsChoice("Zoom", symbol: "rectangle.dashed", caption: "Lens magnifies an area that follows the pointer; the rest of the screen stays as it is.",
                               selection: $zoom.style, label: \.title)
                    .featureSpot("clip-zoom-style")
            }
            Reveal(isShown: zoom.isOn && zoom.style == .lens) {
                SettingsChoice("Lens shape", symbol: "square.on.circle", selection: $zoom.lensShape, label: \.title)
            }
            Reveal(isShown: zoom.isOn && zoom.style == .lens) {
                SettingsChoice("Lens border", symbol: "paintbrush", selection: $zoom.lensBorder.revealing(), label: \.title)
            }
            Reveal(isShown: zoom.isOn && zoom.style == .lens && zoom.lensBorder == .custom) {
                SettingsRow("Border color", symbol: "eyedropper") {
                    ColorPicker("Border color", selection: Binding(get: { zoom.lensBorderColor.color },
                                                                   set: { zoom.lensBorderColor = RGBA($0) }),
                                supportsOpacity: false)
                        .labelsHidden()
                }
            }
            Reveal(isShown: zoom.isOn && zoom.style == .wholeScreen) {
                SettingsChoice("When the pointer moves", symbol: "cursorarrow.motionlines",
                               caption: "Stay where you zoomed keeps the zoomed view still, like macOS Smart Zoom. The pointer stays on that display, stopping 10 pt from its edges.",
                               selection: $zoom.motion, label: \.title)
            }
            Reveal(isShown: zoom.isOn && (zoom.style == .lens || zoom.motion == .follows)) {
                SettingsToggle("Hold still for the laser", symbol: "scope",
                               caption: "Holding the laser's keys, or drawing with it, stops the zoom following the pointer until you let go and the screenshot is taken, so the drawing stays on what it marks.",
                               isOn: $zoom.holdsForLaser)
            }
            Reveal(isShown: zoom.isOn) {
                ValueSlider(title: String(localized: "Zoom amount"), symbol: "plus.magnifyingglass", value: $zoom.amount,
                            range: MagicMouseZoom.amountRange, format: "%.2g×", step: MagicMouseZoom.amountStep, ends: .size)
            }
            Reveal(isShown: zoom.isOn && zoom.style == .lens) {
                ValueSlider(title: String(localized: "Lens size"), symbol: "circle.dashed", value: $zoom.lensSize,
                            range: MagicMouseZoom.lensSizeRange, format: "%.0f pt", spot: "clip-lens-size",
                            step: MagicMouseZoom.lensSizeStep, ends: .size)
            }
            Reveal(isShown: zoom.isOn) {
                ValueSlider(title: String(localized: "Animation length"), symbol: "wand.and.rays", value: $zoom.animationLength,
                            range: MagicMouseZoom.animationLengthRange, format: "%.0f ms", scale: 1000,
                            step: MagicMouseZoom.animationLengthStep, ends: .time)
            }
            Reveal(isShown: zoom.isOn) {
                SettingsToggle("Show zoom when sharing your screen", symbol: "rectangle.inset.filled.and.person.filled",
                               caption: "People in a Slack huddle, Google Meet or other call see the zoom when you share your whole screen. Off, they see your screen as it is. Sharing one window never shows it.",
                               isOn: $zoom.showsInScreenShare)
            }
        }
        .featureSpot("zoom")
        .animation(.reveal, value: zoom.style)
        .animation(.reveal, value: zoom.motion)
        .animation(.reveal, value: zoom.touches.hasMagicMouse)
        .animation(.reveal, value: canRecord)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            canRecord = ScreenRecordingAccess.isAllowed
        }
    }
}

/// Apps where a double tap is left to macOS's own Smart Zoom, so the two never zoom at once.
private struct NativeZoomAppsSection: View {
    @Bindable var zoom: MagicMouseZoom

    var body: some View {
        SettingsCard("macOS Smart Zoom", anchor: "zoom.native") {
            SettingsToggle("Let macOS Smart Zoom work in these apps", symbol: "doc.text.magnifyingglass",
                           caption: "In these apps a double tap zooms the web page, document or image the way macOS does, and Pointer Colors stays out of the way. Turn on Smart zoom in System Settings › Mouse for it to work.",
                           isOn: $zoom.leavesNativeZoom.revealing())
            Reveal(isShown: zoom.leavesNativeZoom) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(zoom.nativeZoomApps) { app in
                        NativeZoomAppRow(app: app) { zoom.removeNativeZoomApp(app.id) }
                    }
                    Button("Add App…", action: chooseApp)
                }
            }
        }
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        zoom.addNativeZoomApp(at: url)
    }
}

/// One listed app: its icon and name, and Remove.
private struct NativeZoomAppRow: View {
    let app: ZoomApp
    let remove: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 12 * scale) {
            icon
            Text(app.name)
            Spacer()
            Button("Remove", role: .destructive, action: remove)
        }
    }

    private var icon: some View {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID)
        return Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application))
            .resizable()
            .frame(width: 26 * scale, height: 26 * scale)
            .accessibilityHidden(true)
    }
}

/// What counts as a double tap, tuned to keep out zooms nobody asked for.
private struct AdvancedTapSection: View {
    @Bindable var zoom: MagicMouseZoom
    /// Read again whenever the app comes forward, as the user may have just changed it.
    @State private var macSmartZoomIsOn = MacSmartZoomSetting.isOn

    var body: some View {
        SettingsCard("Advanced", anchor: "zoom.advanced") {
            Text("These decide what counts as a double tap, and how the zoomed picture is drawn. The tap settings are used to avoid accidental zooms: a finger shifting, resting, brushing or grazing the mouse isn't a tap. Change them only if zooms start or stop by themselves.")
                .appFont(.caption).foregroundStyle(.secondary)
            SettingsChoice(title: Text("Detect double taps with"), symbol: "hand.tap", caption: Text(Self.detectionList),
                           selection: $zoom.tapDetection, label: \.title)
            Reveal(isShown: zoom.tapDetection.usesMacOS && !macSmartZoomIsOn) {
                SettingsRow(symbol: "exclamationmark.triangle.fill", title: Text("Smart zoom is off in System Settings").foregroundStyle(.orange),
                            caption: Text("macOS only sees a double tap with Smart zoom on in System Settings › Mouse.")) {
                    Button("Open…", action: MacSmartZoomSetting.openMouseSettings)
                }
            }
            Reveal(isShown: zoom.tapDetection.usesOwnTaps) {
                ValueSlider(title: String(localized: "Double-tap within"), symbol: "timer", value: $zoom.tapWindow,
                            range: MagicMouseZoom.tapWindowRange, format: "%.0f ms", scale: 1000,
                            step: MagicMouseZoom.tapWindowStep, ends: .time)
                TapLimitRows(zoom: zoom)
            }
            SettingsRow("Enlarge the picture", symbol: "textformat.size",
                        caption: "Pointer Colors zooms a picture of the screen, so none of these can add detail the screen didn't have; apps like Safari redraw themselves instead. Each sample is drawn at your zoom amount, the way the zoom draws it.") {
                EmptyView()
            }
            ZoomUpscalingPicker(selection: $zoom.upscaling, amount: zoom.amount)
        }
        .animation(.reveal, value: zoom.tapDetection)
        .animation(.reveal, value: macSmartZoomIsOn)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            macSmartZoomIsOn = MacSmartZoomSetting.isOn
        }
    }

    /// What each choice does, and which of the settings below it uses.
    private static var detectionList: String {
        [String(localized: "• macOS only: zooms when macOS itself recognizes the double tap, the same way Safari and Chrome do. Needs Smart zoom on in System Settings › Mouse. The tap settings below don't apply; macOS uses its own."),
         String(localized: "• Pointer Colors only: Pointer Colors reads your fingers on the mouse itself, using the double-tap time and tap limits below. Works with Smart zoom off."),
         String(localized: "• Both: zooms only when macOS and Pointer Colors see the same double tap, so it's the strictest. Uses the settings below and needs Smart zoom on.")]
            .joined(separator: "\n")
    }
}

/// What a touch may do and still count as a tap.
private struct TapLimitRows: View {
    @Bindable var zoom: MagicMouseZoom

    var body: some View {
        ValueSlider(title: String(localized: "Shortest tap"), symbol: "hand.tap",
                    caption: String(localized: "A touch shorter than this is a flicker of contact as a finger shifts on the mouse, not a tap. Real taps last 60 ms or more; flickers that zoomed by themselves lasted 17–32 ms."),
                    value: $zoom.shortestTap, range: MagicMouseZoom.shortestTapRange, format: "%.0f ms", scale: 1000,
                    step: MagicMouseZoom.shortestTapStep, ends: .time)
        ValueSlider(title: String(localized: "Longest tap"), symbol: "hand.raised",
                    caption: String(localized: "A touch longer than this is a finger resting or settling on the mouse, not a tap. Real taps last about 90–150 ms; touches that zoomed by themselves lasted 180–210 ms."),
                    value: $zoom.longestTap, range: MagicMouseZoom.longestTapRange, format: "%.0f ms", scale: 1000,
                    step: MagicMouseZoom.longestTapStep, ends: .time)
        ValueSlider(title: String(localized: "Pointer movement during a tap"), symbol: "arrow.up.and.down.and.arrow.left.and.right",
                    caption: String(localized: "A touch that moves the pointer farther than this is a finger brushing the mouse as you move it, not a tap. Real taps move it 0–5 pt; brushes that zoomed by themselves moved it 30 pt or more."),
                    value: $zoom.tapTravel, range: MagicMouseZoom.tapTravelRange, format: "%.0f pt",
                    step: MagicMouseZoom.tapTravelStep, ends: .size)
        ValueSlider(title: String(localized: "Lightest tap"), symbol: "hand.point.up",
                    caption: String(localized: "A touch smaller than this is a finger grazing the side of the mouse, not a tap. Fingertip taps measure 0.6–1.1; grazes that zoomed by themselves, 0.1–0.25."),
                    value: $zoom.lightestTap, range: MagicMouseZoom.lightestTapRange, format: "%.2f",
                    step: MagicMouseZoom.lightestTapStep, ends: .size)
        ValueSlider(title: String(localized: "Wait after a flicker"), symbol: "hourglass",
                    caption: String(localized: "A touch that starts this soon after a flicker of contact is the finger still settling on the mouse, not a tap. A grip change that zoomed by itself tapped 60 ms after its flicker; real double taps came 460 ms or more after one."),
                    value: $zoom.flickerSettle, range: MagicMouseZoom.flickerSettleRange, format: "%.0f ms", scale: 1000,
                    step: MagicMouseZoom.flickerSettleStep, ends: .time)
        Reveal(isShown: !zoom.hasDefaultTapLimits) {
            SettingsRow(symbol: "arrow.counterclockwise", title: Text("Tap limits changed"),
                        caption: Text("Puts the shortest tap, longest tap, pointer movement, lightest tap and wait after a flicker back to 50 ms, 170 ms, 10 pt, 0.5 and 300 ms.")) {
                Button("Reset", action: zoom.restoreTapLimits)
            }
        }
    }
}
