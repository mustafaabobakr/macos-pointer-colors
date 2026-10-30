import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    static let windowID = "preferences"

    let model: AppModel

    @State private var tab: PreferencesTab

    init(model: AppModel, tab: PreferencesTab = .general) {
        self.model = model
        _tab = State(initialValue: tab)
    }

    var body: some View {
        VStack(spacing: 0) {
            PreferencesTabBar(selection: $tab).featureSpot("clip-tab-bar")
            Divider()
            tabContent.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Fixed width, resizable height: drag the window taller to see more of a long tab.
        .frame(width: 560 * model.textScale)
        .frame(minHeight: 380 * model.textScale, idealHeight: 520 * model.textScale, maxHeight: .infinity)
        .appTextScale(model.textScale)
        .preferredColorScheme(model.colorScheme)
    }

    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .general: GeneralPreferences(model: model)
        case .pairs: PairsPreferences(model: model)
        case .automation: AutomationPreferences(model: model)
        case .highlight: HighlightPreferences(highlight: model.highlight, pair: model.menuBarPair, pairs: model.library.visible, pointerScale: model.scale)
        case .speed: TrackingPreferences(tracking: model.tracking)
        case .buttons: ButtonsPreferences(buttons: model.buttons)
        case .shortcuts: ShortcutsPreferences(model: model)
        case .about: AboutPreferences(model: model)
        }
    }
}

enum PreferencesTab: String, CaseIterable, Identifiable {
    case general, pairs, automation, highlight, speed, buttons, shortcuts, about

    var id: Self { self }
    /// Names the tab's screen in docs/features/features.json.
    var slug: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: "General"
        case .pairs: "Pairs"
        case .automation: "Automation"
        case .highlight: "Highlight"
        case .speed: "Speed"
        case .buttons: "Buttons"
        case .shortcuts: "Shortcuts"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .pairs: "cursorarrow"
        case .automation: "wand.and.stars"
        case .highlight: "cursorarrow.rays"
        case .speed: "hare"
        case .buttons: "computermouse"
        case .shortcuts: "command"
        case .about: "info.circle"
        }
    }
}

/// Icon-over-label tabs, like a Settings window's toolbar. A plain window draws TabView as text
/// tabs, and this window can't be a Settings window, which SwiftUI keeps at a fixed size.
private struct PreferencesTabBar: View {
    @Binding var selection: PreferencesTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(PreferencesTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.symbol).font(.system(size: 18)).frame(height: 22)
                        Text(tab.title).appFont(.caption)
                    }
                    .frame(minWidth: 64)
                    .padding(.vertical, 6).padding(.horizontal, 6)
                    .foregroundStyle(selection == tab ? Color.accentColor : .secondary)
                    .background(selection == tab ? Color.primary.opacity(0.08) : .clear,
                                in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
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
            MenuBarSection(model: model)
            Section("Appearance") {
                Picker("Theme", selection: $model.theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .featureSpot("clip-theme")
                Picker("Menu glass", selection: $model.menuGlass) {
                    ForEach(MenuGlass.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Menu tint", selection: $model.menuTint) {
                    ForEach(MenuTint.allCases) { Text($0.title).tag($0) }
                }
                .featureSpot("clip-menu-tint")
                LabeledContent("Tint strength") {
                    Slider(value: $model.menuTintStrength, in: 0.1...0.8)
                        .frame(width: 180)
                }
                .disabled(model.menuTint == .none)
                Picker(selection: $model.textSize) {
                    ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Text size")
                    Text("Size of the menu and this window. Automatic uses Large on big screens.")
                }
            }
            .featureSpot("menu-appearance")
            BackupSection(model: model)
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

/// Where the app shows itself: the menu bar, with the mouse's battery, and the Dock.
private struct MenuBarSection: View {
    @Bindable var model: AppModel

    var body: some View {
        Section("Menu bar and Dock") {
            Picker(selection: $model.menuBarVisibility) {
                ForEach(MenuBarVisibility.allCases) { Text($0.title).tag($0) }
            } label: {
                Text("Show in menu bar")
                if model.menuBarVisibility == .never {
                    Text("Open Pointer Colors again to show Preferences.")
                }
            }
            .featureSpot("clip-menu-bar-visibility")
            if model.menuBarVisibility == .always {
                Picker(selection: $model.batteryDisplay) {
                    ForEach(BatteryDisplay.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("Show mouse battery")
                    Text(batteryCaption)
                }
                .padding(.leading, 20)
                .featureSpot("clip-battery")
            }
            Toggle(isOn: $model.showsInDock) {
                Text("Show in Dock")
                Text("Also lists Pointer Colors in the app switcher.")
            }
        }
        .featureSpot("menu-bar-dock")
        .onAppear { model.tracking.refreshBattery() }
    }

    private var batteryCaption: String {
        guard let level = model.tracking.batteryLevel else { return String(localized: "No connected mouse reports its battery.") }
        return String(localized: "Next to the icon. Your mouse is at \(level)%.")
    }
}

/// Export and import of every preference, for moving to another Mac or keeping a copy.
private struct BackupSection: View {
    let model: AppModel
    @State private var pendingImport: Data?
    @State private var errorMessage: String?

    var body: some View {
        Section {
            LabeledContent {
                HStack {
                    Button("Import…", action: chooseFile)
                    Button("Export all…", action: exportAll).featureSpot("clip-export")
                }
            } label: {
                Text("All settings")
                Text("Pairs, automation, highlight, speed, shortcuts and appearance in one file.")
            }
            if let errorMessage { Text(errorMessage).appFont(.caption).foregroundStyle(.red) }
        } header: {
            Text("Backup")
        }
        .featureSpot("backup")
        .confirmationDialog("Replace all settings?", isPresented: Binding(
            get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }
        )) {
            Button("Import and Relaunch", role: .destructive, action: importPending)
        } message: {
            Text("Your current settings are replaced by the file's, and Pointer Colors relaunches.")
        }
    }

    private func exportAll() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.propertyList]
        panel.nameFieldStringValue = "Pointer Colors Settings.plist"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try model.exportAllSettings().write(to: url)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't export: \(error.localizedDescription)")
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.propertyList]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            pendingImport = try Data(contentsOf: url)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't import that file: \(error.localizedDescription)")
        }
    }

    private func importPending() {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try model.importAllSettings(from: data)
        } catch {
            errorMessage = String(localized: "Couldn't import that file: \(error.localizedDescription)")
        }
    }
}

private struct ShortcutsPreferences: View {
    let model: AppModel

    var body: some View {
        Form {
            Section {
                ForEach(ShortcutAction.allCases) { action in
                    LabeledContent {
                        ShortcutRecorder(combo: model.shortcuts[action]) { combo in
                            model.setShortcut(combo, for: action)
                        } onRecordingChange: { recording in
                            recording ? model.hotKeys.unregisterAll() : model.registerShortcuts()
                        }
                    } label: {
                        Text(action.title)
                        if model.shortcutConflicts.contains(action) {
                            Text("Another app already uses this shortcut.").foregroundStyle(.orange)
                        }
                    }
                }
            } header: {
                Text("Keyboard shortcuts")
            } footer: {
                Text("They work from any app. None are set until you record one.")
                    .appFont(.caption).foregroundStyle(.secondary)
            }
            .featureSpot("shortcuts")
        }
        .formStyle(.grouped)
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
                .appFont(.callout)
                .foregroundStyle(.secondary)
            List(model.library.all) { pair in
                PairRow(model: model, pair: pair) { editing = pair }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            if isAdding || editing != nil { editor }
            HStack {
                Button("Add custom pair") { isAdding = true; editing = nil }.featureSpot("clip-add-custom")
                Spacer()
                Button("Import…", action: importPairs)
                Button("Export…", action: exportPairs).disabled(model.library.custom.isEmpty)
            }
            if let errorMessage { Text(errorMessage).appFont(.caption).foregroundStyle(.red) }
        }
        .featureSpot("custom-pairs")
        .padding(20)
    }

    @ViewBuilder private var editor: some View {
        CustomPairEditor(title: editing == nil ? String(localized: "New custom pair") : String(localized: "Edit pair"), initial: editing) { name, outline, fill in
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
            errorMessage = String(localized: "Couldn't import that file: \(error.localizedDescription)")
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
            errorMessage = String(localized: "Couldn't export: \(error.localizedDescription)")
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
                Text("\(pair.outline.hex) / \(pair.fill.hex)").appFont(.caption, monospacedDigits: true).foregroundStyle(.secondary)
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
            .toggleStyle(.switch).controlSize(.mini)
        }
        .padding(.vertical, 2)
        .featureSpot("clip-row-\(pair.id)")
    }
}

private struct AboutPreferences: View {
    let model: AppModel
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 10) {
            PointerGlyph(pair: PointerPair.featured, lineWidth: 2).frame(height: 48)
            Text("Pointer Colors").appFont(.title2, weight: .bold)
            Text("Version \(version)").foregroundStyle(.secondary)
            if let local = BuildInfo.current.localLabel {
                Text(local).appFont(.caption).foregroundStyle(.orange)
            }
            HStack(spacing: 4) {
                Text("Created by")
                Link("Mostafa Abobakr", destination: URL(string: "https://github.com/mustafaabobakr")!)
            }
            HStack(spacing: 16) {
                Link("Website", destination: URL(string: "https://macos-pointer-colors.pages.dev")!)
                Link("GitHub", destination: URL(string: "https://github.com/mustafaabobakr/macos-pointer-colors")!)
            }
            Text("Changes the same pointer outline, fill and size settings as System Settings › Accessibility › Display.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Divider().frame(maxWidth: 300).padding(.vertical, 6)
            UpdateSection(model: model).featureSpot("updates")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        // Scrolls, so the window can be made shorter than this tab's content.
        .scrollableIfNeeded()
    }
}

private struct UpdateSection: View {
    @Bindable var model: AppModel
    @State private var schedule = UpdateSchedule.saved()

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Check for Updates…") { Task { await model.checkForUpdatesNow() } }
                    .disabled(model.isCheckingForUpdates || model.isInstallingUpdate)
                    .featureSpot("clip-check-updates")
                if model.availableUpdateDownload != nil {
                    Button("Install and Relaunch") { Task { await model.installUpdate() } }
                        .disabled(model.isInstallingUpdate)
                }
                if model.isCheckingForUpdates || model.isInstallingUpdate { ProgressView().controlSize(.small) }
            }
            if let message = model.updateMessage {
                Text(message).appFont(.caption).foregroundStyle(.secondary)
            }
            if let update = model.availableUpdateNotes {
                ReleaseNotesView(version: update.version, notes: update.notes, height: 160)
            }
            if let url = model.availableUpdateURL {
                Link("Download the new version", destination: url)
            }
            Picker("Check automatically", selection: $schedule) {
                ForEach(UpdateSchedule.allCases) { Text($0.title).tag($0) }
            }
            .fixedSize()
            .onChange(of: schedule) { model.updateSchedule = schedule }
            Toggle("Install updates automatically", isOn: $model.installsUpdatesAutomatically)
                .toggleStyle(.checkbox)
        }
    }
}

private extension View {
    /// Centred when it fits, scrolling when the window is shorter than the content.
    func scrollableIfNeeded() -> some View {
        ViewThatFits(in: .vertical) {
            self.frame(maxHeight: .infinity)
            ScrollView { self }
        }
    }
}
