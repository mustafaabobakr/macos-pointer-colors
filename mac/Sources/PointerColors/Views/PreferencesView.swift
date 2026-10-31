import SwiftUI
import UniformTypeIdentifiers

struct PreferencesView: View {
    let model: AppModel

    @State private var router: PreferencesRouter
    @State private var query = ""
    @State private var activeResult: Int?
    @State private var columns = NavigationSplitViewVisibility.all
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel, tab: PreferencesTab = .general) {
        self.model = model
        _router = State(initialValue: PreferencesRouter(tab: tab))
    }

    private var scale: CGFloat { model.textScale }
    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        content
            .frame(minWidth: 760 * scale, minHeight: 500 * scale)
            .modifier(GlassWindowBackground())
            .appTextScale(scale)
            .preferredColorScheme(model.colorScheme)
    }

    // A feature clip draws offscreen in a window with no toolbar, so it gets the sidebar and the
    // page side by side.
    @ViewBuilder private var content: some View {
        if ScreenshotRenderer.isRendering {
            HStack(spacing: 0) {
                sidebar(results: []).frame(width: 220 * scale)
                Divider()
                detail
            }
        } else {
            splitView
        }
    }

    private var splitView: some View {
        let results = SettingsSearch.results(for: query)
        return NavigationSplitView(columnVisibility: $columns) {
            // The field floats at the top, and the list scrolls on under its glass.
            sidebar(results: results)
                .safeAreaInset(edge: .top, spacing: 0) {
                    SidebarSearchField(text: $query, isFocused: $searchFocused)
                        .padding(.horizontal, 10 * scale)
                        // Room above and below, so the field doesn't sit against the toolbar or the list.
                        .padding(.top, 8 * scale)
                        .padding(.bottom, 10 * scale)
                }
            // macOS 26 adds its own sidebar button over the sidebar; the toolbar has ours.
            .toolbar(removing: .sidebarToggle)
            .frame(minWidth: 200 * scale)
            .navigationSplitViewColumnWidth(min: 200 * scale, ideal: 230 * scale, max: 300 * scale)
        } detail: {
            detail
        }
        .onChange(of: query) { activeResult = isSearching && !results.isEmpty ? 0 : nil }
        .toolbar { navigationButtons }
        .background {
            PreferencesEvents(back: router.goBack, forward: router.goForward,
                              isSearchFocused: { searchFocused },
                              moveResult: { moveResult(by: $0, in: results) },
                              openResult: { openActive(in: results) })
        }
    }

    private func sidebar(results: [SettingsSearchResult]) -> some View {
        PreferencesSidebar(router: router, results: results, isSearching: isSearching,
                           activeResult: activeResult, open: open)
    }

    private var detail: some View {
        ScrollViewReader { proxy in
            page
                .id(router.tab)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .environment(\.settingsFocus, router.focus)
                .onChange(of: router.requestID) { scrollToFocus(proxy) }
        }
    }

    @ViewBuilder private var page: some View {
        switch router.tab {
        case .general: GeneralPreferences(model: model)
        case .appearance: AppearancePreferences(model: model)
        case .pairs: PairsPreferences(model: model)
        case .automation: AutomationPreferences(model: model)
        case .highlight: HighlightPreferences(highlight: model.highlight, pair: model.menuBarPair, pairs: model.library.visible, pointerScale: model.scale)
        case .speed: TrackingPreferences(tracking: model.tracking)
        case .buttons: ButtonsPreferences(buttons: model.buttons)
        case .battery: BatteryPreferences(model: model)
        case .shortcuts: ShortcutsPreferences(model: model)
        case .about: AboutPreferences(model: model)
        case .whatsNew: WhatsNewPreferences()
        }
    }

    @ToolbarContentBuilder private var navigationButtons: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            let title = columns == .detailOnly ? String(localized: "Show Sidebar") : String(localized: "Hide Sidebar")
            Button(title, systemImage: "sidebar.left", action: toggleSidebar)
                .keyboardShortcut("s", modifiers: [.control, .command])
                .help(title)
        }
        ToolbarItemGroup(placement: .navigation) {
            Button("Back", systemImage: "chevron.backward", action: router.goBack)
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!router.canGoBack)
                .help("Back")
            Button("Forward", systemImage: "chevron.forward", action: router.goForward)
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!router.canGoForward)
                .help("Forward")
        }
    }

    private func toggleSidebar() {
        let next: NavigationSplitViewVisibility = columns == .detailOnly ? .all : .detailOnly
        withAnimation(reduceMotion ? nil : .default) { columns = next }
    }

    private func open(_ result: SettingsSearchResult) {
        router.show(result.tab, focus: result.anchor)
        query = ""
        activeResult = nil
    }

    private func openActive(in results: [SettingsSearchResult]) -> Bool {
        let index = activeResult ?? 0
        guard isSearching, results.indices.contains(index) else { return false }
        open(results[index])
        return true
    }

    private func moveResult(by delta: Int, in results: [SettingsSearchResult]) -> Bool {
        guard isSearching, !results.isEmpty else { return false }
        activeResult = min(max((activeResult ?? -1) + delta, 0), results.count - 1)
        return true
    }

    /// Scrolls to the card a search result asked for, then lets its outline fade.
    private func scrollToFocus(_ proxy: ScrollViewProxy) {
        guard let focus = router.focus else { return }
        let request = router.requestID
        Task { @MainActor in
            // The page is new when the result is on another one; let it lay out first.
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { proxy.scrollTo(focus, anchor: .top) }
            try? await Task.sleep(for: .seconds(1.6))
            router.clearFocus(request)
        }
    }
}

/// On macOS 26 and later the window shows the desktop through a blur behind its glass cards.
private struct GlassWindowBackground: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !reduceTransparency {
            content.containerBackground(.ultraThinMaterial, for: .window)
        } else {
            content
        }
    }
}

private struct GeneralPreferences: View {
    @Bindable var model: AppModel
    @State private var reapply = false
    @State private var sound = false

    var body: some View {
        SettingsPage("General") {
            SettingsCard("Startup", anchor: "general.startup") {
                SettingsToggle("Launch at login", symbol: "power", caption: "Start Pointer Colors when you log in.",
                               isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                SettingsToggle("Re-apply my pair when the app starts", symbol: "arrow.clockwise",
                               caption: "Puts your colors and size back if something reset them.", isOn: $reapply)
                    .onChange(of: reapply) { model.settings.reapplyAtLaunch = reapply }
                SettingsToggle("Draw the menu-bar icon in my colors", symbol: "paintpalette",
                               caption: "Off shows a plain icon that follows the menu bar.", isOn: $model.iconInPairColors)
                SettingsToggle("Play a sound when a pair is applied", symbol: "speaker.wave.2", isOn: $sound)
                    .onChange(of: sound) { model.settings.playSoundOnApply = sound }
            }
            MenuBarSection(model: model)
            BackupSection(model: model)
            SettingsCard("Permission", anchor: "general.permission") {
                SettingsRow("Pointer colors and size", symbol: "lock.shield") {
                    if model.needsFullDiskAccess {
                        Button("Grant Full Disk Access…") { model.openFullDiskAccessSettings() }
                    } else {
                        Label("Allowed", systemImage: "checkmark.circle").foregroundStyle(.green)
                    }
                }
                NotificationPermissionRow()
            }
            FeedbackCard()
        }
        .onAppear {
            reapply = model.settings.reapplyAtLaunch
            sound = model.settings.playSoundOnApply
            model.refreshFromSystem()
        }
    }
}

/// Preferences › Appearance: the app's theme, the menu's glass and tint, and the text size.
private struct AppearancePreferences: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsPage("Appearance") {
            SettingsCard("Theme", anchor: "appearance.theme") {
                ThemePicker(selection: $model.theme)
                    .featureSpot("clip-theme")
                Text("Applies to Pointer Colors' own windows and menu, not to the whole Mac.")
                    .appFont(.caption).foregroundStyle(.secondary)
            }
            .featureSpot("menu-appearance")
            SettingsCard(anchor: "appearance.text") {
                SettingsMenu("Text size", symbol: "textformat.size",
                             caption: "Size of the menu and this window. Automatic uses Large on big screens.",
                             selection: $model.textSize) {
                    ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                }
            }
            .featureSpot("menu-appearance")
            SettingsCard("App icon", anchor: "appearance.icon") {
                AppIconPicker(selection: $model.appIconStyle)
                    .featureSpot("clip-app-icon")
                    .frame(maxWidth: .infinity)
                Text("Follow System uses Icon & widget style in System Settings › Appearance. Default and Dark keep that design in the Dock while Pointer Colors runs; Finder always follows the system.")
                    .appFont(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .featureSpot("app-icon")
            MenuLookCard(model: model)
                .featureSpot("menu-appearance")
        }
    }
}

/// The menu's glass and tint.
private struct MenuLookCard: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsCard("Menu", anchor: "appearance.menu") {
            SettingsToggle("Show current pair at the top", symbol: "rectangle.topthird.inset.filled",
                           caption: "Its colors, buttons to copy their hex codes, and whether it's applied.",
                           isOn: $model.menuShowsCurrentPair)
            SettingsRow("Menu glass", symbol: "square.on.square") {
                Picker("Menu glass", selection: $model.menuGlass) {
                    ForEach(MenuGlass.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            SettingsMenu("Menu tint", symbol: "drop", selection: $model.menuTint) {
                ForEach(MenuTint.allCases) { Text($0.title).tag($0) }
            }
            .featureSpot("clip-menu-tint")
            SettingsRow("Tint strength", symbol: "slider.horizontal.3") {
                Slider(value: $model.menuTintStrength, in: 0.1...0.8)
                    .accessibilityLabel("Tint strength")
                    .frame(width: 180)
            }
            .disabled(model.menuTint == .none)
        }
    }
}

/// Where the app shows itself: the menu bar and the Dock. The battery shown there is on the Battery page.
private struct MenuBarSection: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsCard("Menu bar and Dock", anchor: "general.menuBar") {
            SettingsMenu(title: Text("Show in menu bar"), symbol: "menubar.rectangle",
                         caption: model.menuBarVisibility == .never ? Text("Open Pointer Colors again to show Preferences.") : nil,
                         selection: $model.menuBarVisibility) {
                ForEach(MenuBarVisibility.allCases) { Text($0.title).tag($0) }
            }
            .featureSpot("clip-menu-bar-visibility")
            SettingsToggle("Show in Dock", symbol: "dock.rectangle",
                           caption: "Also lists Pointer Colors in the app switcher.", isOn: $model.showsInDock)
        }
        .featureSpot("menu-bar-dock")
    }
}

/// Opens a new GitHub issue, for a bug report or an idea.
private struct FeedbackCard: View {
    private static let newIssue = URL(string: "https://github.com/mustafaabobakr/macos-pointer-colors/issues/new")!

    var body: some View {
        SettingsCard(anchor: "general.feedback") {
            SettingsRow("Feedback", symbol: "bubble.left.and.text.bubble.right",
                        caption: "Send a bug report or feature idea straight to the person who makes Pointer Colors.") {
                Link("Send Feedback", destination: Self.newIssue)
                    .buttonStyle(.bordered)
            }
        }
    }
}

/// Export and import of every preference, for moving to another Mac or keeping a copy.
private struct BackupSection: View {
    let model: AppModel
    @State private var pendingImport: Data?
    @State private var errorMessage: String?

    var body: some View {
        SettingsCard("Backup", anchor: "general.backup") {
            SettingsRow("All settings", symbol: "externaldrive",
                        caption: "Pairs, automation, highlight, speed, buttons, battery, shortcuts and appearance in one file.") {
                HStack {
                    Button("Import…", action: chooseFile)
                    Button("Export all…", action: exportAll).featureSpot("clip-export")
                }
            }
            if let errorMessage { Text(errorMessage).appFont(.caption).foregroundStyle(.red) }
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
        SettingsPage("Shortcuts") {
            SettingsCard("Keyboard shortcuts", anchor: "shortcuts.keys") {
                ForEach(ShortcutAction.allCases) { action in
                    SettingsRow(symbol: action.symbol, title: Text(action.title), caption: conflict(action)) {
                        ShortcutRecorder(combo: model.shortcuts[action]) { combo in
                            model.setShortcut(combo, for: action)
                        } onRecordingChange: { recording in
                            recording ? model.hotKeys.unregisterAll() : model.registerShortcuts()
                        }
                    }
                }
                Text("They work from any app. None are set until you record one.")
                    .appFont(.caption).foregroundStyle(.secondary)
            }
            .featureSpot("shortcuts")
        }
    }

    private func conflict(_ action: ShortcutAction) -> Text? {
        guard model.shortcutConflicts.contains(action) else { return nil }
        return Text("Another app already uses this shortcut.").foregroundStyle(.orange)
    }
}

private struct PairsPreferences: View {
    let model: AppModel
    @State private var editing: PointerPair?
    @State private var isAdding = false
    @State private var errorMessage: String?

    var body: some View {
        SettingsPage("Pairs") {
            SettingsCard(anchor: "pairs.list") {
                Text("Hidden pairs stay out of the menu-bar grid. Custom pairs can be edited or deleted.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                ForEach(model.library.all) { pair in
                    if pair.id != model.library.all.first?.id { Divider() }
                    PairRow(model: model, pair: pair) { editing = pair }
                }
            }
            .featureSpot("custom-pairs")
            if isAdding || editing != nil { editor }
            HStack {
                Button("Add custom pair") { isAdding = true; editing = nil }.featureSpot("clip-add-custom")
                Spacer()
                Button("Import…", action: importPairs)
                Button("Export…", action: exportPairs).disabled(model.library.custom.isEmpty)
            }
            if let errorMessage { Text(errorMessage).appFont(.caption).foregroundStyle(.red) }
        }
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
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 12 * scale) {
            PointerGlyph(pair: pair)
                .frame(width: 26 * scale, height: 20 * scale)
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(pair.name)
                Text("\(pair.outline.hex) / \(pair.fill.hex)").appFont(.caption, monospacedDigits: true).foregroundStyle(.secondary)
            }
            Spacer()
            if pair.isCustom {
                Button("Edit", action: onEdit).controlSize(.small)
                Button("Delete", role: .destructive) { model.removeCustom(pair) }.controlSize(.small)
            }
            Toggle("Show \(pair.name)", isOn: Binding(
                get: { !model.library.hiddenIDs.contains(pair.id) },
                set: { model.setHidden(!$0, pair: pair) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .featureSpot("clip-row-\(pair.id)")
    }
}

private struct AboutPreferences: View {
    let model: AppModel
    @Environment(\.appTextScale) private var scale
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        SettingsPage("About") {
            SettingsCard(anchor: "about.app") {
                VStack(spacing: 10 * scale) {
                    // The same icon as in the Dock.
                    Image(nsImage: model.appIconStyle.image ?? NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96 * scale, height: 96 * scale)
                        .accessibilityHidden(true)
                    Text("Pointer Colors").appFont(.title2, weight: .bold)
                    Text("Version \(version)").appFont(.callout).foregroundStyle(.secondary)
                    if let local = BuildInfo.current.localLabel {
                        Text(local).appFont(.caption).foregroundStyle(.orange)
                    }
                    Text("Changes the same pointer outline, fill and size settings as System Settings › Accessibility › Display.")
                        .appFont(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10 * scale) {
                        GitHubStarButton()
                        WebsiteButton()
                    }
                    .padding(.top, 4 * scale)
                    Text("Like Pointer Colors? A star on GitHub helps more people discover it and makes a real difference to its development.")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text("Created by")
                        Link("Mostafa Abobakr", destination: URL(string: "https://github.com/mustafaabobakr")!)
                    }
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8 * scale)
            }
            SettingsCard("Updates", anchor: "about.updates") {
                UpdateSection(model: model)
            }
            .featureSpot("updates")
        }
    }
}

private struct UpdateSection: View {
    @Bindable var model: AppModel
    @State private var schedule = UpdateSchedule.saved()

    var body: some View {
        SettingsRow(symbol: "arrow.down.circle", title: Text("Check for updates"), caption: model.updateMessage.map { Text($0) }) {
            HStack {
                if model.isCheckingForUpdates || model.isInstallingUpdate { ProgressView().controlSize(.small) }
                if model.availableUpdateDownload != nil {
                    Button("Install and Relaunch") { Task { await model.installUpdate() } }
                        .disabled(model.isInstallingUpdate)
                }
                Button("Check for Updates…") { Task { await model.checkForUpdatesNow() } }
                    .disabled(model.isCheckingForUpdates || model.isInstallingUpdate)
                    .featureSpot("clip-check-updates")
            }
        }
        if let update = model.availableUpdateNotes {
            ReleaseNotesView(version: update.version, notes: update.notes, height: 160)
        }
        if let url = model.availableUpdateURL {
            Link("Download the new version", destination: url)
        }
        SettingsMenu("Check automatically", symbol: "calendar", selection: $schedule) {
            ForEach(UpdateSchedule.allCases) { Text($0.title).tag($0) }
        }
        .onChange(of: schedule) { model.updateSchedule = schedule }
        SettingsToggle("Install updates automatically", symbol: "arrow.triangle.2.circlepath",
                       isOn: $model.installsUpdatesAutomatically)
    }
}
