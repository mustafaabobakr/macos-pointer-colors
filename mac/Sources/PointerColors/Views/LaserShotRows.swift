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
                if isOn { ScreenRecordingAccess.request() }
            }
        Reveal(isShown: highlight.laserOn && highlight.laserShotOn) { options }
            .onAppear(perform: dropMissingOpener)
    }

    @ViewBuilder private var options: some View {
        SettingsToggle("Only while zoomed", symbol: "plus.magnifyingglass",
                       caption: "Takes a screenshot only while a Magic Mouse zoom is up. Without a zoom, the laser just draws.",
                       isOn: $highlight.laserShotOnlyZoomed)
        ValueSlider(title: String(localized: "Margin around the trail"), symbol: "rectangle.dashed",
                    value: $highlight.laserShotMargin, range: PointerHighlight.shotMarginRange,
                    format: "%.0f pt", spot: "clip-laser-shot-margin", step: 5, ends: .size)
        SettingsToggle("Capture the whole zoom while zoomed", symbol: "plus.magnifyingglass",
                       caption: "With a Magic Mouse zoom up, takes everything the zoom shows, the whole screen or the lens, without the margin.",
                       isOn: $highlight.laserShotWholeZoom)
        SettingsToggle("Show the laser in the screenshot", symbol: "scribble",
                       caption: "Off captures what's under the trail, without it.",
                       isOn: $highlight.laserShotIncludesTrail)
        SettingsToggle("Copy to the clipboard", symbol: "doc.on.clipboard", isOn: $highlight.laserShotCopies)
        SettingsToggle("Save to a folder", symbol: "folder", isOn: $highlight.laserShotSaves.revealing())
        Reveal(isShown: highlight.laserShotSaves) { folderRow }
        // A menu even with four or fewer apps: segments don't show the app icons well.
        SettingsChoice("Open in", symbol: "arrow.up.forward.app",
                       caption: "Opens each screenshot to mark up. Without Save to a folder, it's kept in the app's Screenshots folder below.",
                       selection: $highlight.laserShotOpener, options: LaserShotOpener.allCases.filter(\.isAvailable),
                       style: .menu) { OpenerLabel(opener: $0) }
        SettingsChoice("Zoom out after the screenshot", symbol: "minus.magnifyingglass",
                       caption: "Ends the Magic Mouse zoom once the screenshot is taken: a whole-screen zoom, a lens, or both.",
                       selection: $highlight.laserShotZoomOut, label: \.title)
            .featureSpot("clip-laser-shot-zoom-out")
        UnsavedShotsRow()
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

/// The app's own Screenshots folder, where shots that were only opened are kept: how much is in
/// it, a way to look, and a way to empty it for good.
private struct UnsavedShotsRow: View {
    @State private var usage = (count: 0, bytes: 0)
    @State private var isConfirming = false
    @State private var failure: String?
    private let store = LaserShotStore()

    var body: some View {
        SettingsRow(symbol: "photo.stack", title: Text("Screenshots kept by the app"), caption: caption) {
            Button("Show in Finder", action: store.showInFinder)
            Button("Delete All…", role: .destructive) { isConfirming = true }
                .disabled(usage.count == 0)
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .confirmationDialog(Text("Delete \(usage.count) screenshots for good?"), isPresented: $isConfirming) {
            Button("Delete All", role: .destructive, action: deleteAll)
        } message: {
            Text("They're removed right away, not moved to the Trash, and can't be recovered.")
        }
    }

    private var caption: Text {
        if let failure { return Text(failure) }
        let size = usage.bytes.formatted(.byteCount(style: .file))
        return Text("Shots opened without Save to a folder. \(usage.count) now, \(size).")
    }

    private func refresh() {
        usage = store.usage
    }

    private func deleteAll() {
        do {
            try store.deleteAll()
            failure = nil
        } catch {
            failure = String(localized: "Couldn't delete them all: \(error.localizedDescription)")
        }
        refresh()
    }
}
