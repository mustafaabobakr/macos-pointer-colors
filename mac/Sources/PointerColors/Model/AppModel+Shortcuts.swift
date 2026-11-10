import Foundation

extension AppModel {
    func setShortcut(_ combo: KeyCombo?, for action: ShortcutAction) {
        var all = shortcuts
        all[action] = combo
        // One combo can't trigger two actions; the newest assignment wins.
        if let combo {
            for (other, existing) in all where other != action && existing == combo { all[other] = nil }
        }
        shortcuts = all
        settings.shortcuts = all
        registerShortcuts()
    }

    /// Registers every recorded shortcut and notes the ones another app already uses.
    func registerShortcuts() {
        let actions = ShortcutAction.allCases
        let bindings = shortcuts.compactMap { action, combo -> (id: UInt32, combo: KeyCombo, action: () -> Void)? in
            guard let index = actions.firstIndex(of: action) else { return nil }
            return (UInt32(index + 1), combo, { [weak self] in self?.perform(action) })
        }
        let failed = hotKeys.register(bindings)
        shortcutConflicts = Set(failed.compactMap { id in actions.indices.contains(Int(id) - 1) ? actions[Int(id) - 1] : nil })
    }

    func perform(_ action: ShortcutAction) {
        switch action {
        case .nextPair: applyNeighbour(offset: 1)
        case .previousPair: applyNeighbour(offset: -1)
        case .biggerPointer: stepScale(bigger: true)
        case .smallerPointer: stepScale(bigger: false)
        case .resetPointer: reset()
        }
    }

    private func stepScale(bigger: Bool) {
        let limits = SystemPointer.minimumScale...SystemPointer.maximumScale
        setScale(SizeStep.next(from: scale, step: settings.sizeShortcutStep, bigger: bigger, limits: limits))
    }

    /// Selects and applies the visible pair before or after the current one, wrapping around.
    private func applyNeighbour(offset: Int) {
        let pairs = library.visible
        guard !pairs.isEmpty else { return }
        let current = pairs.firstIndex { $0.id == selectedID } ?? 0
        let next = pairs[(current + offset + pairs.count) % pairs.count]
        select(next)
        applySelected()
    }
}
