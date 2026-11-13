import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Preferences › Zoom: a Magic Mouse double tap zooms in on what's under the pointer.
struct ZoomPreferences: View {
    let zoom: MagicMouseZoom

    var body: some View {
        SettingsPage("Zoom") {
            AccessibilityNotice(isNeeded: zoom.needsAccessibility)
            SmartZoomSection(zoom: zoom)
            Reveal(isShown: zoom.isOn) {
                NativeZoomAppsSection(zoom: zoom)
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
            Reveal(isShown: zoom.isOn && !canRecord) {
                SettingsRow(symbol: "exclamationmark.triangle.fill", title: Text("Needs Screen Recording").foregroundStyle(.orange),
                            caption: Text("Pointer Colors draws the zoom from a live picture of the screen. Nothing is saved or sent anywhere.")) {
                    Button("Allow…", action: ScreenRecordingAccess.request)
                }
            }
            Reveal(isShown: zoom.isOn && !zoom.touches.hasMagicMouse) {
                SettingsRow(symbol: "computermouse", title: Text("No Magic Mouse connected").foregroundStyle(.secondary),
                            caption: Text("Zoom starts working as soon as one connects.")) {
                    EmptyView()
                }
            }
            Reveal(isShown: zoom.isOn) {
                SettingsChoice("Zoom", symbol: "rectangle.dashed", caption: "Lens magnifies an area that follows the pointer; the rest of the screen stays as it is.",
                               selection: $zoom.style, label: \.title)
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
            Reveal(isShown: zoom.isOn) {
                ValueSlider(title: String(localized: "Zoom amount"), symbol: "plus.magnifyingglass", value: $zoom.amount,
                            range: MagicMouseZoom.amountRange, format: "%.2g×", step: MagicMouseZoom.amountStep, ends: .size)
            }
            Reveal(isShown: zoom.isOn && zoom.style == .lens) {
                ValueSlider(title: String(localized: "Lens size"), symbol: "circle.dashed", value: $zoom.lensSize,
                            range: MagicMouseZoom.lensSizeRange, format: "%.0f pt", step: MagicMouseZoom.lensSizeStep, ends: .size)
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
            Reveal(isShown: zoom.isOn) {
                ValueSlider(title: String(localized: "Double-tap within"), symbol: "timer", value: $zoom.tapWindow,
                            range: MagicMouseZoom.tapWindowRange, format: "%.0f ms", scale: 1000,
                            step: MagicMouseZoom.tapWindowStep, ends: .time)
            }
        }
        .animation(.reveal, value: zoom.style)
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
