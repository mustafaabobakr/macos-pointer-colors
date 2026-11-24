import XCTest
@testable import PointerColors

final class MouseReconnectTests: XCTestCase {
    func testOnlyApplePointingPeripheralsMatch() {
        // Magic Mouse: class of device 0x2580, minor 0x20. Magic Trackpad: 0x2594, minor 0x25.
        XCTAssertTrue(ApplePointerClass.matches(major: 0x05, minor: 0x20, vendor: 0x004C))
        XCTAssertTrue(ApplePointerClass.matches(major: 0x05, minor: 0x25, vendor: 0x004C))
        XCTAssertFalse(ApplePointerClass.matches(major: 0x05, minor: 0x10, vendor: 0x004C), "Keyboard")
        XCTAssertFalse(ApplePointerClass.matches(major: 0x05, minor: 0x30, vendor: 0x004C), "Keyboard with pointer")
        XCTAssertFalse(ApplePointerClass.matches(major: 0x05, minor: 0x20, vendor: 0x046D), "Another maker's mouse")
        XCTAssertFalse(ApplePointerClass.matches(major: 0x05, minor: 0x20, vendor: nil))
        XCTAssertFalse(ApplePointerClass.matches(major: 0x04, minor: 0x20, vendor: 0x004C), "Audio")
    }

    func testStateAfterAnAttempt() {
        let mouse = PairedPointer(address: "a", name: "Mouse", isConnected: true)
        let pad = PairedPointer(address: "b", name: "Trackpad", isConnected: false)
        XCTAssertEqual(MouseReconnectState(after: []), .noDevice)
        XCTAssertEqual(MouseReconnectState(after: [mouse]), .connected(["Mouse"]))
        XCTAssertEqual(MouseReconnectState(after: [mouse, pad]), .failed(["Trackpad"]))
        XCTAssertTrue(MouseReconnectState.reconnecting("Mouse").isBusy)
        XCTAssertFalse(MouseReconnectState.failed(["Mouse"]).isBusy)
    }

    @MainActor func testReconnectOnMenuOpenIsOnByDefault() {
        let fresh = AppSettings(defaults: UserDefaults(suiteName: "MouseReconnect-\(UUID().uuidString)")!)
        XCTAssertTrue(fresh.reconnectsMouseOnMenuOpen)
        XCTAssertTrue(AppSettings.factory.reconnectsMouseOnMenuOpen)
    }

    @MainActor func testTurnedOffSurvivesBackupAndImport() throws {
        let sourceName = "MouseReconnectSource-\(UUID().uuidString)"
        let targetName = "MouseReconnectTarget-\(UUID().uuidString)"
        let source = UserDefaults(suiteName: sourceName)!
        let target = UserDefaults(suiteName: targetName)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        AppSettings(defaults: source).reconnectsMouseOnMenuOpen = false
        let data = try SettingsBackup(defaults: source, domain: sourceName, historyFolder: folder).export(launchAtLogin: false)
        try SettingsBackup(defaults: target, domain: targetName, historyFolder: folder).restore(from: data)
        XCTAssertFalse(AppSettings(defaults: target).reconnectsMouseOnMenuOpen)
    }
}
