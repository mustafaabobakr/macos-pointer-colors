import AppKit
import Carbon.HIToolbox
import XCTest
@testable import PointerColors

final class KeyComboTests: XCTestCase {
    private func keyEvent(_ characters: String, keyCode: Int, flags: NSEvent.ModifierFlags) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0,
                         context: nil, characters: characters, charactersIgnoringModifiers: characters,
                         isARepeat: false, keyCode: UInt16(keyCode))!
    }

    func testRecordsModifiersInMacOrder() {
        let combo = KeyCombo(event: keyEvent("p", keyCode: kVK_ANSI_P, flags: [.command, .option, .shift]))
        XCTAssertEqual(combo?.displayString, "⌥⇧⌘P")
        XCTAssertEqual(combo?.keyCode, UInt32(kVK_ANSI_P))
    }

    func testShiftAloneIsNotEnough() {
        XCTAssertNil(KeyCombo(event: keyEvent("p", keyCode: kVK_ANSI_P, flags: [.shift])))
        XCTAssertNil(KeyCombo(event: keyEvent("p", keyCode: kVK_ANSI_P, flags: [])))
    }

    func testArrowKeysGetSymbols() {
        let combo = KeyCombo(event: keyEvent("\u{F703}", keyCode: kVK_RightArrow, flags: [.control]))
        XCTAssertEqual(combo?.displayString, "⌃→")
    }
}
