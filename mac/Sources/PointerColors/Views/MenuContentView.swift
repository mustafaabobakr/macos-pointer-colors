import SwiftUI

/// The popover shown from the menu-bar icon.
struct MenuContentView: View {
    @Bindable var model: AppModel
    @State private var isAddingCustom = false
    @Environment(\.openSettings) private var openSettings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            sizeRow
            VisibilityPreviews(pair: model.selectedPair, pointerScale: model.scale)
            pairGrid
            DisplayColorsSection(automation: model.automation, pairs: model.library.visible)
            if isAddingCustom {
                CustomPairEditor(title: String(localized: "New custom pair"), initial: nil) { name, outline, fill in
                    model.addCustom(name: name, outline: outline, fill: fill)
                    model.applySelected()
                    isAddingCustom = false
                } onCancel: {
                    isAddingCustom = false
                }
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 380 * scale)
        .appTextScale(scale)
        .onAppear { model.refreshFromSystem() }
    }

    private var scale: CGFloat { model.textScale }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(white: 0.96))
                PointerGlyph(pair: model.selectedPair, lineWidth: 1.8)
                    .frame(height: (16 + 12 * model.scale) * scale)
            }
            .frame(width: 104 * scale, height: 104 * scale)

            VStack(alignment: .leading, spacing: 6) {
                Text(model.selectedPair.name).appFont(.title3, weight: .bold)
                HStack(spacing: 6) {
                    HexButton(label: String(localized: "Outline"), color: model.selectedPair.outline) { model.copyHex(outline: true) }
                    HexButton(label: String(localized: "Fill"), color: model.selectedPair.fill) { model.copyHex(outline: false) }
                }
                Text(model.status.message)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ContrastWarning(pair: model.selectedPair)
            }
        }
    }

    private var sizeRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if model.automation.perDisplaySizes {
                    DisplaySizeList(automation: model.automation, scale: scale)
                } else {
                    sizeControls
                }
                PerDisplayToggle(automation: model.automation)
            }
        }
    }

    private var sizeControls: some View {
        HStack(spacing: 10) {
            Text("Pointer size").appFont(.caption).frame(width: 74 * scale, alignment: .leading)
            Slider(value: Binding(get: { model.scale }, set: { model.setScale($0) }),
                   in: SystemPointer.minimumScale...SystemPointer.maximumScale) {
                Text("Pointer size")
            } minimumValueLabel: {
                Image(systemName: "textformat.size.smaller").accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: "textformat.size.larger").accessibilityHidden(true)
            }
            .labelsHidden()
            Text(String(format: "%.2f×", model.scale))
                .appFont(.caption, monospacedDigits: true)
                .frame(width: 40 * scale, alignment: .trailing)
            Button { model.resetScale() } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(model.isDefaultScale)
            .help("Reset pointer size to default")
            .accessibilityLabel("Reset pointer size to default")
        }
    }

    private var pairGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAIRS").appFont(.caption2, weight: .semibold).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(model.library.visible) { pair in
                    PairTile(pair: pair, isSelected: pair.id == model.selectedID, scale: scale) { model.choose(pair) }
                }
                Button { isAddingCustom = true } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "plus").appFont(.body)
                        Text("Custom").appFont(.tile)
                    }
                    .frame(maxWidth: .infinity, minHeight: 58 * scale)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style: .init(lineWidth: 1, dash: [3])).foregroundStyle(.tertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a custom pair")
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 2) {
            MenuRow(title: String(localized: "Preferences…"), shortcut: "⌘,") {
                NSApp.activate()
                openSettings()
            }
            .keyboardShortcut(",")
            MenuRow(title: model.isCheckingForUpdates ? String(localized: "Checking for Updates…") : String(localized: "Check for Updates…"),
                    shortcut: nil) {
                if let url = model.availableUpdateURL { NSWorkspace.shared.open(url) } else { Task { await model.checkForUpdates() } }
            }
            .disabled(model.isCheckingForUpdates)
            if let message = model.updateMessage {
                Text(model.availableUpdateURL == nil ? message : String(localized: "\(message) Click above to download."))
                    .appFont(.caption2).foregroundStyle(.secondary).padding(.horizontal, 6)
            }
            MenuRow(title: String(localized: "Browse pairs on the website"), shortcut: nil) {
                NSWorkspace.shared.open(URL(string: "https://macos-pointer-colors.pages.dev")!)
            }
            MenuRow(title: String(localized: "Quit"), shortcut: "⌘Q") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

private struct HexButton: View {
    let label: String
    let color: RGBA
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(color.color).frame(width: 10, height: 10)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.3)))
                Text("\(label) \(color.hex)").appFont(.caption, monospacedDigits: true)
            }
        }
        .controlSize(.small)
        .help("Copy \(color.hex)")
        .accessibilityLabel("Copy \(label.lowercased()) hex \(color.hex)")
    }
}

private struct PairTile: View {
    let pair: PointerPair
    let isSelected: Bool
    let scale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                PointerGlyph(pair: pair).frame(height: 23 * scale)
                Text(pair.name)
                    .appFont(.tile)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 58 * scale)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor.opacity(0.18) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Color.accentColor : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pair.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct MenuRow: View {
    let title: String
    let shortcut: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut { Text(shortcut).foregroundStyle(.secondary) }
            }
            .frame(minHeight: 26)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Per-display sizes live in the menu so it's clear which display each slider changes.
private struct PerDisplayToggle: View {
    @Bindable var automation: Automation

    var body: some View {
        Toggle("Separate size for each display", isOn: $automation.perDisplaySizes)
            .toggleStyle(.checkbox)
            .appFont(.caption)
    }
}

/// One slider per connected display; the one under the pointer is marked "current".
private struct DisplaySizeList: View {
    let automation: Automation
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(automation.displays) { display in
                DisplaySizeRow(automation: automation, display: display,
                               isCurrent: display.id == automation.lastDisplayID, scale: scale)
            }
        }
    }
}

private struct DisplaySizeRow: View {
    let automation: Automation
    let display: DisplayInfo
    let isCurrent: Bool
    let scale: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : "display")
                    .frame(width: 20 * scale, alignment: .center)
                    .accessibilityHidden(true)
                Text(display.name).appFont(.caption).lineLimit(1)
                if isCurrent {
                    Text("(current)").appFont(.caption, weight: .semibold).foregroundStyle(Color.accentColor)
                }
            }
            HStack(spacing: 8) {
                Slider(value: Binding(get: { automation.size(for: display) },
                                      set: { automation.setSize($0, for: display) }),
                       in: SystemPointer.minimumScale...SystemPointer.maximumScale)
                    .accessibilityLabel("Pointer size on \(display.name)")
                Text(String(format: "%.2f×", automation.size(for: display)))
                    .appFont(.caption, monospacedDigits: true)
                    .frame(width: 40 * scale, alignment: .trailing)
                Button { automation.setSize(SystemPointer.minimumScale, for: display) } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(automation.size(for: display) == SystemPointer.minimumScale)
                .help("Reset pointer size to default")
                .accessibilityLabel("Reset pointer size to default")
            }
        }
    }
}
