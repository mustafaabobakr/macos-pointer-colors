import AppKit
import Foundation
import Testing
@testable import PointerColors

@Suite struct GeneralOptionsTests {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "GeneralOptionsTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    @Test func sizeStepDefaultsToAQuarterAndStaysInRange() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.sizeShortcutStep == 0.25)
        settings.sizeShortcutStep = 0.5
        #expect(AppSettings(defaults: defaults).sizeShortcutStep == 0.5)
        settings.sizeShortcutStep = 5
        #expect(settings.sizeShortcutStep == SizeStep.range.upperBound)
        settings.sizeShortcutStep = 0
        #expect(settings.sizeShortcutStep == SizeStep.range.lowerBound)
    }

    @Test(arguments: [(1.0, 0.25, true, 1.25), (1.0, 0.25, false, 1.0), (3.9, 0.5, true, 4.0),
                      (2.0, 0.1, false, 1.9), (2.0, 1.0, true, 3.0)])
    func sizeStepMovesWithinThePointerLimits(scale: Double, step: Double, bigger: Bool, expected: Double) {
        let next = SizeStep.next(from: scale, step: step, bigger: bigger, limits: 1...4)
        #expect(abs(next - expected) < 0.000_1)
    }

    @Test func applySoundDefaultsToPopAndRejectsUnknownNames() {
        let (defaults, name) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = AppSettings(defaults: defaults)
        #expect(settings.applySound == "Pop")
        settings.applySound = "Tink"
        #expect(AppSettings(defaults: defaults).applySound == "Tink")
        defaults.set("NoSuchSound", forKey: "applySound")
        #expect(settings.applySound == "Pop")
    }

    @Test func everyOfferedSoundExistsOnThisMac() {
        for name in ApplySound.names {
            #expect(NSSound(named: name) != nil, "\(name)")
        }
    }

    @Test func exportAndImportCarryBothSettings() throws {
        let (source, sourceName) = makeDefaults()
        let (target, targetName) = makeDefaults()
        defer {
            source.removePersistentDomain(forName: sourceName)
            target.removePersistentDomain(forName: targetName)
        }
        AppSettings(defaults: source).applySound = "Glass"
        AppSettings(defaults: source).sizeShortcutStep = 0.75
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)

        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = AppSettings(defaults: target)
        #expect(restored.applySound == "Glass")
        #expect(restored.sizeShortcutStep == 0.75)
    }
}
