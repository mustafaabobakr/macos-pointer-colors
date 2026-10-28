import AppKit
import SwiftUI

/// The window that offers a new version: what changed, and skip, install on quit, or install and
/// relaunch. An AppKit window so the model can open it from a background check.
@MainActor
final class UpdateWindowController {
    private var window: NSWindow?

    func show(model: AppModel) {
        let window = window ?? makeWindow(model: model)
        self.window = window
        if !window.isVisible { window.center() }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }

    private func makeWindow(model: AppModel) -> NSWindow {
        let window = NSWindow(contentViewController: NSHostingController(rootView: UpdatePromptView(model: model)))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = String(localized: "Software Update")
        window.isReleasedWhenClosed = false
        return window
    }
}

struct UpdatePromptView: View {
    @Bindable var model: AppModel

    private var version: String { model.availableUpdateVersion ?? "" }
    private var isReady: Bool { model.preparedUpdate?.version == version && !version.isEmpty }
    private var isBusy: Bool { model.isPreparingUpdate || model.isInstallingUpdate }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            notes
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Automatically download and install updates in the future", isOn: $model.installsUpdatesAutomatically)
                    .toggleStyle(.checkbox)
                if let error = model.updateInstallError {
                    Text("Couldn't install: \(error)").appFont(.caption).foregroundStyle(.red)
                }
                buttons
            }
            .featureSpot("update-window")
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(width: 580 * model.textScale)
        .appTextScale(model.textScale)
        .preferredColorScheme(model.colorScheme)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64 * model.textScale, height: 64 * model.textScale)
            VStack(alignment: .leading, spacing: 6) {
                Text(isReady ? "A new version of Pointer Colors is ready to install!" : "A new version of Pointer Colors is available!")
                    .appFont(.body, weight: .bold)
                Text(isReady
                     ? "Pointer Colors \(version) has been downloaded and is ready to use! Would you like to install it and relaunch Pointer Colors now?"
                     : "Pointer Colors \(version) is available. You have \(UpdateChecker().currentVersion). Would you like to install it and relaunch Pointer Colors now?")
                    .appFont(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var notes: some View {
        ScrollView {
            Text(ReleaseNotesView.rendered(model.availableUpdateNotes?.notes ?? String(localized: "No release notes.")))
                .appFont(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
        .frame(height: 220 * model.textScale)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Skip This Version", action: model.skipAvailableUpdate).featureSpot("clip-skip")
            Spacer()
            if isBusy { ProgressView().controlSize(.small) }
            Button("Install on Quit") { Task { await model.installUpdateOnQuit() } }.featureSpot("clip-install-on-quit")
            Button("Install and Relaunch") { Task { await model.installUpdate() } }
                .keyboardShortcut(.defaultAction)
                .featureSpot("clip-install")
        }
        .controlSize(.large)
        .disabled(isBusy || model.availableUpdateDownload == nil)
    }
}
