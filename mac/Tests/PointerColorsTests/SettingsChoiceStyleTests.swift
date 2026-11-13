import Testing
@testable import PointerColors

struct SettingsChoiceStyleTests {
    @Test(arguments: [1, 2, 3, 4])
    func `up to four options show as segments`(count: Int) {
        #expect(SettingsChoiceStyle(optionCount: count) == .segmented)
    }

    @Test(arguments: [5, 8, 14])
    func `five or more options show as a menu`(count: Int) {
        #expect(SettingsChoiceStyle(optionCount: count) == .menu)
    }
}
