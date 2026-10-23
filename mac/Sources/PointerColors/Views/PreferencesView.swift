import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralPreferences(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            PairsPreferences(model: model)
                .tabItem { Label("Pairs", systemImage: "cursorarrow") }
            AboutPreferences()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 520)
    }
}

private struct GeneralPreferences: View {
    @Bindable var model: AppModel
    @State private var reapply = false
    @State private var sound = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) })) {
                    Text("Launch at login")
                    Text("Start Pointer Colors when you log in.")
                }
                Toggle(isOn: $reapply) {
                    Text("Re-apply my pair when the app starts")
                    Text("Puts your colors and size back if something reset them.")
                }
                .onChange(of: reapply) { model.settings.reapplyAtLaunch = reapply }
                Toggle(isOn: $model.iconInPairColors) {
                    Text("Draw the menu-bar icon in my colors")
                    Text("Off shows a plain icon that follows the menu bar.")
                }
                Toggle("Play a sound when a pair is applied", isOn: $sound)
                    .onChange(of: sound) { model.settings.playSoundOnApply = sound }
            }
            Section("Permission") {
                LabeledContent("Pointer colors and size") {
                    if model.needsFullDiskAccess {
                        Button("Grant Full Disk Access…") { model.openFullDiskAccessSettings() }
                    } else {
                        Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(.green)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            reapply = model.settings.reapplyAtLaunch
            sound = model.settings.playSoundOnApply
            model.refreshFromSystem()
        }
    }
}

private struct PairsPreferences: View {
    let model: AppModel
    @State private var editing: PointerPair?
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hidden pairs stay out of the menu-bar grid. Custom pairs can be edited or deleted.")
                .font(.callout)
                .foregroundStyle(.secondary)
            List(model.library.all) { pair in
                PairRow(model: model, pair: pair) { editing = pair }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            if isAdding || editing != nil { editor }
            HStack {
                Button("Add custom pair") { isAdding = true; editing = nil }
                Spacer()
                Button("Import…", action: importPairs)
                Button("Export…", action: exportPairs).disabled(model.library.custom.isEmpty)
            }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }
        .padding(20)
    }

    @ViewBuilder private var editor: some View {
        CustomPairEditor(title: editing == nil ? "New custom pair" : "Edit pair", initial: editing) { name, outline, fill in
            if var pair = editing {
                pair.name = name; pair.outline = outline; pair.fill = fill
                model.updateCustom(pair)
            } else {
                model.addCustom(name: name, outline: outline, fill: fill)
            }
            closeEditor()
        } onCancel: {
            closeEditor()
        }
        .id(editing?.id ?? "new")
    }

    private func closeEditor() {
        editing = nil
        isAdding = false
    }

    private func importPairs() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.importCustom(from: Data(contentsOf: url))
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't import that file: \(error.localizedDescription)"
        }
    }

    private func exportPairs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "pointer-pairs.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportCustom().write(to: url)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't export: \(error.localizedDescription)"
        }
    }
}

private struct PairRow: View {
    let model: AppModel
    let pair: PointerPair
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PointerGlyph(pair: pair).frame(height: 20)
            VStack(alignment: .leading) {
                Text(pair.name)
                Text("\(pair.outline.hex) / \(pair.fill.hex)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            if pair.isCustom {
                Button("Edit", action: onEdit).controlSize(.small)
                Button("Delete", role: .destructive) { model.removeCustom(pair) }.controlSize(.small)
            }
            Toggle("Show", isOn: Binding(
                get: { !model.library.hiddenIDs.contains(pair.id) },
                set: { model.setHidden(!$0, pair: pair) }
            ))
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 2)
    }
}

private struct AboutPreferences: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 10) {
            PointerGlyph(pair: PointerPair.builtIns[0], lineWidth: 2).frame(height: 48)
            Text("Pointer Colors").font(.title2.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Link("Website", destination: URL(string: "https://macos-pointer-colors.pages.dev")!)
                Link("GitHub", destination: URL(string: "https://github.com/mustafaabobakr/macos-pointer-colors")!)
            }
            Text("Changes the same pointer outline, fill and size settings as System Settings › Accessibility › Display.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
