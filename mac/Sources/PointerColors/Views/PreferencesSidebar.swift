import SwiftUI

/// Preferences' pages under headings that fold away, or while searching, the matching pages and
/// settings, the highlighted one opening on Return.
struct PreferencesSidebar: View {
    let router: PreferencesRouter
    let results: [SettingsSearchResult]
    let isSearching: Bool
    let activeResult: Int?
    let open: (SettingsSearchResult) -> Void
    @State private var collapsed: Set<PreferencesGroup> = []
    /// The page just clicked, handed to the router once the list's update is over.
    @State private var pick: PreferencesTab?
    @Environment(\.appTextScale) private var scale

    var body: some View {
        ScrollViewReader { proxy in
            List(selection: selection) {
                if isSearching { searchRows } else { pageRows }
            }
            .listStyle(.sidebar)
            .environment(\.sidebarRowSize, scale > 1.1 ? .large : .medium)
            .overlay { if isSearching && results.isEmpty { noMatches } }
            .onChange(of: pick) { _, tab in
                guard let tab else { return }
                pick = nil
                router.show(tab)
            }
            .onChange(of: activeResult) { _, index in
                guard let index, results.indices.contains(index) else { return }
                proxy.scrollTo(results[index].id)
            }
            .onChange(of: router.tab) { _, tab in collapsed.remove(PreferencesGroup.containing(tab)) }
        }
    }

    private var selection: Binding<PreferencesTab?> {
        Binding(get: { isSearching ? nil : pick ?? router.tab }, set: { pick = $0 })
    }

    private var pageRows: some View {
        ForEach(PreferencesGroup.allCases) { group in
            Section {
                if !collapsed.contains(group) {
                    ForEach(group.tabs) { tab in
                        SidebarRow(title: Text(tab.title), symbol: tab.symbol, isSelected: router.tab == tab)
                            .tag(tab)
                    }
                }
            } header: {
                GroupHeader(group: group, isCollapsed: collapsed.contains(group)) { toggle(group) }
            }
        }
    }

    private var searchRows: some View {
        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
            Button { open(result) } label: {
                SidebarRow(title: Text(result.title), symbol: result.symbol, isSelected: false)
                    .fontWeight(result.isPage ? .semibold : .regular)
                    .padding(.leading, result.isPage ? 0 : 18 * scale)
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(index == activeResult ? Color.accentColor.opacity(0.18) : .clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(index == activeResult ? .isSelected : [])
            .id(result.id)
        }
    }

    private var noMatches: some View {
        Text("No matches").appFont(.callout).foregroundStyle(.secondary)
    }

    private func toggle(_ group: PreferencesGroup) {
        if !collapsed.insert(group).inserted { collapsed.remove(group) }
    }
}

/// A page or result: its symbol fitted to one box, so wide ones like the battery line up.
private struct SidebarRow: View {
    let title: Text
    let symbol: String
    let isSelected: Bool
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 9 * scale) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: 17 * scale, height: 15 * scale)
                .foregroundStyle(isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
                .accessibilityHidden(true)
            title.appFont(.body)
        }
        // Room between rows that grows with the text, so large sizes don't crowd.
        .padding(.vertical, 3 * scale)
    }
}

/// A group's heading, which folds its pages away and back.
private struct GroupHeader: View {
    let group: PreferencesGroup
    let isCollapsed: Bool
    let toggle: () -> Void
    @Environment(\.appTextScale) private var scale

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9 * scale, weight: .semibold))
                    .frame(width: 12 * scale)
                Text(group.title).appFont(.caption, weight: .semibold)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCollapsed ? Text("Collapsed") : Text("Expanded"))
    }
}
