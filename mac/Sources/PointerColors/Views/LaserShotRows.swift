import CoreGraphics
import SwiftUI

/// Preferences › Laser › Screenshots: a picture of the area around each finished trail, and
/// where it goes.
struct LaserShotRows: View {
    @Bindable var highlight: PointerHighlight

    var body: some View {
        SettingsToggle("Take a screenshot of each drawing", symbol: "camera.viewfinder",
                       caption: "When you let go after drawing a trail, captures the area around it. Needs Screen Recording access, which macOS asks for the first time.",
                       isOn: $highlight.laserShotOn.revealing())
            .onChange(of: highlight.laserShotOn) { _, isOn in
                if isOn, !CGPreflightScreenCaptureAccess() { CGRequestScreenCaptureAccess() }
            }
        Reveal(isShown: highlight.laserShotOn) { options }
            .onAppear(perform: dropMissingOpener)
    }

    @ViewBuilder private var options: some View {
        ValueSlider(title: String(localized: "Margin around the trail"), symbol: "rectangle.dashed",
                    value: $highlight.laserShotMargin, range: PointerHighlight.shotMarginRange,
                    format: "%.0f pt", step: 5, ends: .size)
        SettingsToggle("Show the laser in the screenshot", symbol: "scribble",
                       caption: "Off captures what's under the trail, without it.",
                       isOn: $highlight.laserShotIncludesTrail)
        SettingsToggle("Copy to the clipboard", symbol: "doc.on.clipboard", isOn: $highlight.laserShotCopies)
        SettingsToggle("Save to a folder", symbol: "folder", isOn: $highlight.laserShotSaves.revealing())
        Reveal(isShown: highlight.laserShotSaves) { folderRow }
        SettingsMenu("Open in", symbol: "arrow.up.forward.app",
                     caption: "Opens each screenshot to mark up. Without Save to a folder, it opens from a temporary file you can discard.",
                     selection: $highlight.laserShotOpener) {
            ForEach(LaserShotOpener.allCases.filter(\.isAvailable)) { OpenerLabel(opener: $0).tag($0) }
        }
    }

    /// Without this, a chosen app that has since been removed would leave the menu showing nothing:
    /// it falls back to the default app, as `LaserShotOpener.open` already does.
    private func dropMissingOpener() {
        if !highlight.laserShotOpener.isAvailable { highlight.laserShotOpener = .defaultApp }
    }

    private var folderRow: some View {
        SettingsRow(symbol: "folder.badge.gearshape", title: Text("Folder"),
                    caption: Text(verbatim: highlight.laserShotFolder)) {
            Button("Choose…", action: chooseFolder)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(filePath: highlight.laserShotFolder, directoryHint: .isDirectory)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        highlight.laserShotFolder = url.path(percentEncoded: false)
    }
}

/// One Open in choice in the menu: the app's icon, large enough to recognize, and its name.
private struct OpenerLabel: View {
    let opener: LaserShotOpener

    var body: some View {
        Label {
            Text(opener.menuTitle)
        } icon: {
            if let icon = opener.menuIcon(size: 24) { Image(nsImage: icon) }
        }
    }
}
