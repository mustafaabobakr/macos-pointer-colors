import XCTest
@testable import PointerColors

final class RGBATests: XCTestCase {
    func testHexRoundTrip() {
        XCTAssertEqual(RGBA(hex: "#00FFDA")?.hex, "00FFDA")
        XCTAssertEqual(RGBA(hex: "008a59")?.hex, "008A59")
    }

    func testRejectsMalformedHex() {
        XCTAssertNil(RGBA(hex: "FFF"))
        XCTAssertNil(RGBA(hex: "GGGGGG"))
    }

    func testPreferenceDictionaryRoundTrip() {
        let color = RGBA(hex: "0A84FF")!
        XCTAssertEqual(RGBA(preferenceValue: color.preferenceValue)?.hex, "0A84FF")
    }

    /// macOS stores 0.854902 for DA; the pair must still be recognised as applied.
    func testMatchesRoundedPreferenceValues() {
        let stored = RGBA(red: 0, green: 1, blue: 0.854902)
        let fill = RGBA(red: 0, green: 0.5411764705882353, blue: 0.349019)
        XCTAssertTrue(PointerPair.builtIns.first { $0.id == "aqua-mint" }!.matches(outline: stored, fill: fill))
    }
}

final class PairLinkTests: XCTestCase {
    func testParsesWebsiteLink() {
        let link = PairLink(url: URL(string: "pointercolors://add?name=Aqua%20mint&outline=00FFDA&fill=008A59")!)
        XCTAssertEqual(link?.name, "Aqua mint")
        XCTAssertEqual(link?.outline.hex, "00FFDA")
        XCTAssertEqual(link?.fill.hex, "008A59")
    }

    func testRejectsBadColorsAndOtherSchemes() {
        XCTAssertNil(PairLink(url: URL(string: "pointercolors://add?outline=ZZZ&fill=008A59")!))
        XCTAssertNil(PairLink(url: URL(string: "https://add?outline=00FFDA&fill=008A59")!))
        XCTAssertNil(PairLink(url: URL(string: "pointercolors://delete?outline=00FFDA&fill=008A59")!))
    }

    func testCapsLongNamesAndFillsMissingOnes() {
        let long = String(repeating: "a", count: 100)
        XCTAssertEqual(PairLink(url: URL(string: "pointercolors://add?name=\(long)&outline=FFFFFF&fill=000000")!)?.name.count, 40)
        XCTAssertEqual(PairLink(url: URL(string: "pointercolors://add?outline=FFFFFF&fill=000000")!)?.name, "From the website")
    }
}

final class ContrastTests: XCTestCase {
    func testWhiteOnBlackIsMaximum() {
        XCTAssertEqual(RGBA(hex: "FFFFFF")!.contrast(with: RGBA(hex: "000000")!), 21, accuracy: 0.01)
    }

    func testClassicIsVisibleEverywhere() {
        XCTAssertNil(PairVisibility(.macOSLight).warning)
    }

    func testPastelPairIsHardOnLight() {
        let pastel = PointerPair(id: "p", name: "Pastel", outline: RGBA(hex: "FFF5F0")!, fill: RGBA(hex: "FFE3D8")!)
        let visibility = PairVisibility(pastel)
        XCTAssertTrue(visibility.hardOnLight)
        XCTAssertFalse(visibility.hardOnDark)
    }
}

final class TextSizeTests: XCTestCase {
    func testAutomaticIsLargeOnlyOnWideScreens() {
        XCTAssertEqual(TextSize.automatic.factor(screenWidth: 1512), 1)
        XCTAssertEqual(TextSize.automatic.factor(screenWidth: 2560), TextSize.large.factor(screenWidth: 0))
    }

    func testFixedSizesIgnoreScreen() {
        XCTAssertEqual(TextSize.huge.factor(screenWidth: 800), 1.5)
        XCTAssertEqual(TextSize.standard.factor(screenWidth: 5000), 1)
    }
}

final class PairLibraryTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "PairLibraryTests-\(UUID().uuidString)")
    }

    func testCustomPairsPersist() {
        var library = PairLibrary(defaults: defaults)
        library.add(.custom(name: "Mine", outline: RGBA(hex: "FFFFFF")!, fill: RGBA(hex: "FF6FA8")!))
        XCTAssertEqual(PairLibrary(defaults: defaults).custom.map(\.name), ["Mine"])
    }

    func testHiddenPairsLeaveVisibleList() {
        var library = PairLibrary(defaults: defaults)
        library.setHidden(true, id: "glacier")
        XCTAssertFalse(library.visible.contains { $0.id == "glacier" })
        XCTAssertEqual(library.all.count, PointerPair.builtIns.count)
    }

    func testRemoveCustomAlsoClearsHidden() {
        var library = PairLibrary(defaults: defaults)
        let pair = PointerPair.custom(name: "Temp", outline: RGBA(hex: "000000")!, fill: RGBA(hex: "FFFFFF")!)
        library.add(pair)
        library.setHidden(true, id: pair.id)
        library.remove(id: pair.id)
        XCTAssertTrue(library.custom.isEmpty)
        XCTAssertFalse(library.hiddenIDs.contains(pair.id))
    }

    func testExportImportRoundTrip() throws {
        var source = PairLibrary(defaults: defaults)
        source.add(.custom(name: "Exported", outline: RGBA(hex: "112233")!, fill: RGBA(hex: "445566")!))
        var target = PairLibrary(defaults: UserDefaults(suiteName: "target-\(UUID().uuidString)")!)
        try target.importCustom(from: source.exportCustom())
        XCTAssertEqual(target.custom.map(\.fill.hex), ["445566"])
    }
}

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparisonIsNumeric() {
        XCTAssertTrue(UpdateChecker.isNewer("0.10.0", than: "0.9.3"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0", than: "0.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.1"))
        XCTAssertFalse(UpdateChecker.isNewer("0.1.0", than: "0.2.0"))
    }

    func testReadsGitHubRelease() {
        let json = #"{"tag_name":"v0.2.0","html_url":"https://github.com/x/y/releases/tag/v0.2.0"}"#.data(using: .utf8)!
        let result = UpdateChecker.result(data: json, status: 200, current: "0.1.0")
        XCTAssertEqual(result, .available(version: "0.2.0", url: URL(string: "https://github.com/x/y/releases/tag/v0.2.0")!, download: nil, notes: nil))
        XCTAssertEqual(UpdateChecker.result(data: json, status: 200, current: "0.2.0"), .upToDate)
    }

    func testReadsTheDMGForInstallingInPlace() {
        let json = #"""
        {"tag_name":"v0.3.0","html_url":"https://github.com/x/y/releases/tag/v0.3.0","assets":[
          {"name":"Notes.txt","browser_download_url":"https://github.com/x/y/releases/download/v0.3.0/Notes.txt"},
          {"name":"Pointer-Colors.dmg","browser_download_url":"https://github.com/x/y/releases/download/v0.3.0/Pointer-Colors.dmg"}]}
        """#.data(using: .utf8)!
        let result = UpdateChecker.result(data: json, status: 200, current: "0.2.0")
        XCTAssertEqual(result, .available(version: "0.3.0",
                                          url: URL(string: "https://github.com/x/y/releases/tag/v0.3.0")!,
                                          download: URL(string: "https://github.com/x/y/releases/download/v0.3.0/Pointer-Colors.dmg")!,
                                          notes: nil))
    }

    func testWhatsNewStopsAtTheInstallInstructions() {
        let body = """
        **Pointer Colors 0.3.3** adds things.

        - **One thing.** Details.

        **Updating from 0.3.0:** open the menu.

        **Install:** open the DMG.
        """
        XCTAssertEqual(UpdateChecker.whatsNew(in: body), "**Pointer Colors 0.3.3** adds things.\n\n- **One thing.** Details.")
        XCTAssertEqual(UpdateChecker.whatsNew(in: "Just notes."), "Just notes.")
        let withShots = "- **One.** A.\n\n  ![One](https://x/one.png)\n\n  ![Two](https://x/two.png)\n\n- **Two.** B.\n\n**Install:** open it."
        XCTAssertEqual(UpdateChecker.whatsNew(in: withShots), "- **One.** A.\n\n- **Two.** B.")
        XCTAssertNil(UpdateChecker.whatsNew(in: "**Install:** open the DMG."))
        XCTAssertNil(UpdateChecker.whatsNew(in: nil))
    }

    func testMissingReleasesAndErrors() {
        XCTAssertEqual(UpdateChecker.result(data: Data(), status: 404, current: "0.1.0"), .noReleases)
        XCTAssertEqual(UpdateChecker.result(data: Data(), status: 500, current: "0.1.0"), .failed("GitHub answered 500."))
    }
}

final class AppSettingsTests: XCTestCase {
    func testAppPairsFollowThePointerByDefault() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "AppSettingsTests-\(UUID().uuidString)")!)
        XCTAssertEqual(settings.appRuleTrigger, .pointer)
        settings.appRuleTrigger = .frontmost
        XCTAssertEqual(settings.appRuleTrigger, .frontmost)
    }
}

final class AppUpdaterTests: XCTestCase {
    func testRefusesCopiesThatCantReplaceThemselves() {
        let translocated = URL(fileURLWithPath: "/private/var/folders/x/AppTranslocation/ABC/d/Pointer Colors.app")
        XCTAssertEqual(AppUpdater.installBlocker(for: translocated), .notInstalled)
        // A folder the app can't write to, like /System/Applications.
        XCTAssertEqual(AppUpdater.installBlocker(for: URL(fileURLWithPath: "/System/Applications/Calculator.app")), .folderNotWritable)
        let writable = FileManager.default.temporaryDirectory.appendingPathComponent("Pointer Colors.app")
        XCTAssertNil(AppUpdater.installBlocker(for: writable))
    }
}

final class UpdateScheduleTests: XCTestCase {
    func testDueOnlyAfterThePeriod() {
        let now = Date()
        let hours: (Double) -> Date = { now.addingTimeInterval(-$0 * 3600) }
        XCTAssertFalse(UpdateSchedule.daily.isDue(lastCheck: hours(23), now: now))
        XCTAssertTrue(UpdateSchedule.daily.isDue(lastCheck: hours(24), now: now))
        XCTAssertFalse(UpdateSchedule.weekly.isDue(lastCheck: hours(24 * 6), now: now))
        XCTAssertTrue(UpdateSchedule.monthly.isDue(lastCheck: hours(24 * 30), now: now))
        XCTAssertTrue(UpdateSchedule.daily.isDue(lastCheck: nil, now: now))
        XCTAssertFalse(UpdateSchedule.off.isDue(lastCheck: nil, now: now))
    }

    func testDailyByDefaultAndSaved() {
        let defaults = UserDefaults(suiteName: "UpdateScheduleTests-\(UUID().uuidString)")!
        XCTAssertEqual(UpdateSchedule.saved(in: defaults), .daily)
        UpdateSchedule.weekly.save(in: defaults)
        XCTAssertEqual(UpdateSchedule.saved(in: defaults), .weekly)
    }
}

@MainActor
final class PointerHighlightTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "PointerHighlightTests-\(UUID().uuidString)")!
    }

    func testOffByDefaultAndRemembered() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertFalse(highlight.pulseOn)
        XCTAssertFalse(highlight.laserOn)
        XCTAssertFalse(highlight.showsRing)
        XCTAssertFalse(highlight.isActive)
        highlight.laserOn = true
        highlight.laserUsesPairColor = false
        highlight.laserColor = RGBA(hex: "112233")!
        highlight.pulseDuration = 1.2
        let reopened = PointerHighlight(defaults: defaults)
        XCTAssertTrue(reopened.laserOn)
        XCTAssertFalse(reopened.pulseOn)
        XCTAssertTrue(reopened.isActive)
        XCTAssertFalse(reopened.laserUsesPairColor)
        XCTAssertEqual(reopened.laserColor.hex, "112233")
        XCTAssertEqual(reopened.pulseDuration, 1.2)
    }

    func testColorsFollowThePairUnlessOverridden() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        let pair = PointerPair.featured
        XCTAssertEqual(highlight.pulseColor(for: pair), pair.highlightColor)
        XCTAssertEqual(highlight.laserColors(for: pair).glow, pair.highlightColor)
        highlight.pulseUsesPairColor = false
        highlight.laserUsesPairColor = false
        XCTAssertEqual(highlight.pulseColor(for: pair), highlight.pulseColor)
        XCTAssertEqual(highlight.laserColors(for: pair).glow, highlight.laserColor)
        XCTAssertEqual(highlight.laserColors(for: pair).outline, pair.darkColor)
    }

    func testLaserOutlineIsThePairsDarkColorUnlessChanged() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.laserOutline, .dark, "the default")
        let black = RGBA(red: 0, green: 0, blue: 0), yellow = RGBA(red: 1, green: 0.9, blue: 0)
        let pair = PointerPair.custom(name: "Test", outline: black, fill: yellow)
        XCTAssertEqual(highlight.laserColors(for: pair).glow, yellow)
        XCTAssertEqual(highlight.laserColors(for: pair).outline, black)
        let flipped = PointerPair.custom(name: "Flipped", outline: yellow, fill: black)
        XCTAssertEqual(highlight.laserColors(for: flipped).outline, black)
        highlight.laserOutline = .laser
        XCTAssertEqual(highlight.laserColors(for: pair).outline, yellow)
        highlight.laserOutline = .none
        XCTAssertEqual(highlight.laserColors(for: pair).outline, highlight.laserColors(for: pair).middle)
        XCTAssertEqual(PointerHighlight(defaults: defaults).laserOutline, .none, "saved")
    }

    func testEarlierSingleChoiceCarriesOver() {
        let defaults = makeDefaults()
        defaults.set("pulse", forKey: "highlightMode")
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertTrue(highlight.pulseOn)
        XCTAssertFalse(highlight.laserOn)
    }

    func testOneClickWithBothOnPulsesAndStartsATrail() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.pulseOn = true
        highlight.laserOn = true
        let scene = HighlightScene()
        scene.press(at: CGPoint(x: 10, y: 10), now: 0, isLeft: true, keysHeld: false, settings: highlight)
        scene.drag(to: CGPoint(x: 40, y: 10), now: 0.1, keysHeld: false, settings: highlight)
        XCTAssertEqual(scene.pulses.count, 1)
        XCTAssertEqual(scene.strokes.count, 1)
        XCTAssertNotNil(scene.laserDot)
    }

    func testHighlightUsesThePairsColorfulSideNotABlackOutline() {
        let highlighter = PointerPair(id: "h", name: "Highlighter", outline: RGBA(hex: "000000")!, fill: RGBA(hex: "FFFF00")!)
        XCTAssertEqual(highlighter.highlightColor.hex, "FFFF00")
        let aquaMint = PointerPair(id: "a", name: "Aqua mint", outline: RGBA(hex: "00FFDA")!, fill: RGBA(hex: "008A59")!)
        XCTAssertEqual(aquaMint.highlightColor.hex, "00FFDA")
        let macOSDark = PointerPair(id: "d", name: "macOS dark", outline: RGBA(hex: "000000")!, fill: RGBA(hex: "FFFFFF")!)
        XCTAssertEqual(macOSDark.highlightColor.hex, "FFFFFF")
    }

    func testEachPairCanHaveItsOwnColors() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        let pair = PointerPair.featured
        highlight.setPulseColor(RGBA(hex: "FF0000")!, for: pair)
        highlight.setLaserColor(RGBA(hex: "0000FF")!, for: pair)
        let reopened = PointerHighlight(defaults: defaults)
        XCTAssertEqual(reopened.pulseColor(for: pair).hex, "FF0000")
        XCTAssertEqual(reopened.laserColors(for: pair).glow.hex, "0000FF")
        reopened.setPulseColor(nil, for: pair)
        XCTAssertEqual(reopened.pulseColor(for: pair), pair.highlightColor)
        reopened.laserUsesPairColor = false
        XCTAssertEqual(reopened.laserColors(for: pair).glow, reopened.laserColor)
    }

    func testLaserNeedingKeysDrawsOnlyWithThem() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.laserOn = true
        highlight.laserNeedsKeys = true
        let scene = HighlightScene()
        scene.press(at: .zero, now: 0, isLeft: true, keysHeld: false, settings: highlight)
        scene.drag(to: CGPoint(x: 30, y: 0), now: 0.1, keysHeld: false, settings: highlight)
        XCTAssertTrue(scene.strokes.isEmpty)
        scene.press(at: .zero, now: 0.2, isLeft: true, keysHeld: true, settings: highlight)
        scene.drag(to: CGPoint(x: 30, y: 0), now: 0.3, keysHeld: true, settings: highlight)
        XCTAssertEqual(scene.strokes.count, 1)
    }

    func testLaserKeysDefaultToOptionAndAreSaved() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.laserKeys, .option)
        XCTAssertEqual(highlight.laserKeys.title, "⌥ Option")
        highlight.laserKeys = [.control, .option]
        XCTAssertEqual(highlight.laserKeys.title, "⌃⌥")
        XCTAssertFalse(highlight.laserKeysHeld(in: .option))
        XCTAssertTrue(highlight.laserKeysHeld(in: [.control, .option, .shift]))
        XCTAssertEqual(PointerHighlight(defaults: defaults).laserKeys, [.control, .option])
    }

    func testLaserDotCanShowOnlyWhileDrawing() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.laserOn = true
        highlight.laserDot = .whileDrawing
        let scene = HighlightScene()
        scene.move(to: .zero, now: 0, settings: highlight)
        XCTAssertNil(scene.laserDot, "a plain move shows no dot")
        scene.press(at: .zero, now: 0.1, isLeft: true, keysHeld: false, settings: highlight)
        scene.drag(to: CGPoint(x: 30, y: 0), now: 0.2, keysHeld: false, settings: highlight)
        XCTAssertNotNil(scene.laserDot, "drawing shows it")
    }

    func testLaserDotModes() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.laserOn = true
        XCTAssertEqual(highlight.laserDot, .always, "the default")
        XCTAssertTrue(highlight.laserDotShows(drawing: false))
        highlight.laserDot = .hidden
        XCTAssertFalse(highlight.laserDotShows(drawing: true))
    }

    func testQuickClickShowsNoHoldButALongPressDoes() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.pulseOn = true
        highlight.pulseShowsHold = true
        let scene = HighlightScene()
        scene.press(at: .zero, now: 0, isLeft: true, keysHeld: false, settings: highlight)
        scene.release(at: 0.1)
        XCTAssertNil(scene.hold, "a click is just a pulse")
        XCTAssertEqual(scene.pulses.count, 1)

        scene.press(at: .zero, now: 1, isLeft: true, keysHeld: false, settings: highlight)
        scene.move(to: CGPoint(x: 20, y: 5), now: 1.3, settings: highlight)
        scene.release(at: 1.6)
        XCTAssertEqual(scene.hold?.releasedAt, 1.6, "the held ring fades on release")
        XCTAssertEqual(scene.pulses.last?.start, 1.6, "and a pulse goes out on release")
        XCTAssertEqual(scene.pulses.last?.point, CGPoint(x: 20, y: 5))
        XCTAssertEqual(scene.hold?.point, CGPoint(x: 20, y: 5), "the held ring follows the pointer")
        XCTAssertTrue(scene.prune(at: 1.6 + Hold.release + 0.01))
        XCTAssertNil(scene.hold)
    }

    func testLongPressesAreOffByDefault() {
        let highlight = PointerHighlight(defaults: makeDefaults())
        highlight.pulseOn = true
        XCTAssertFalse(highlight.pulseShowsHold)
        let scene = HighlightScene()
        scene.press(at: .zero, now: 0, isLeft: true, keysHeld: false, settings: highlight)
        XCTAssertNil(scene.hold)
    }

    func testPulseStyleIsRingByDefaultAndRemembered() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertEqual(highlight.pulseStyle, .ring)
        highlight.pulseStyle = .ripple
        XCTAssertEqual(PointerHighlight(defaults: defaults).pulseStyle, .ripple)
    }

    func testPressIsOffByDefaultAndRemembered() {
        let defaults = makeDefaults()
        let highlight = PointerHighlight(defaults: defaults)
        XCTAssertFalse(highlight.shrinksOnPress)
        XCTAssertFalse(highlight.shrinks(isLeft: true), "off means no press shrinks")
        XCTAssertEqual(highlight.pressScale, 0.88)
        XCTAssertEqual(highlight.pressCurve, .easeOut)
        highlight.shrinksOnPress = true
        highlight.pressScale = 0.7
        highlight.pressDownDuration = 0.2
        highlight.pressUpDuration = 0
        highlight.pressCurve = .bounce
        highlight.shrinksOnRightClick = false
        let reopened = PointerHighlight(defaults: defaults)
        XCTAssertTrue(reopened.shrinksOnPress)
        XCTAssertEqual(reopened.pressScale, 0.7)
        XCTAssertEqual(reopened.pressDownDuration, 0.2)
        XCTAssertEqual(reopened.pressUpDuration, 0)
        XCTAssertEqual(reopened.pressCurve, .bounce)
        XCTAssertTrue(reopened.shrinks(isLeft: true))
        XCTAssertFalse(reopened.shrinks(isLeft: false), "right clicks left out")
    }

    func testPressCurvesStartAtZeroAndLandOnOne() {
        for curve in PressCurve.allCases {
            XCTAssertEqual(curve.value(at: 0), 0, accuracy: 1e-9, curve.rawValue)
            XCTAssertEqual(curve.value(at: 1), 1, accuracy: 1e-9, curve.rawValue)
        }
        XCTAssertGreaterThan(PressCurve.bounce.value(at: 0.8), 1, "a bounce goes past the end")
    }
}

final class SettingsBackupTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "SettingsBackupTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (defaults, name)
    }

    @MainActor
    func testRoundTripCarriesPressSettings() throws {
        let (source, sourceName) = makeDefaults()
        let highlight = PointerHighlight(defaults: source)
        highlight.shrinksOnPress = true
        highlight.pressScale = 0.6
        highlight.pressDownDuration = 0.15
        highlight.pressUpDuration = 0.25
        highlight.pressCurve = .linear
        highlight.shrinksOnRightClick = false
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)

        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = PointerHighlight(defaults: target)
        XCTAssertTrue(restored.shrinksOnPress)
        XCTAssertEqual(restored.pressScale, 0.6)
        XCTAssertEqual(restored.pressDownDuration, 0.15)
        XCTAssertEqual(restored.pressUpDuration, 0.25)
        XCTAssertEqual(restored.pressCurve, .linear)
        XCTAssertFalse(restored.shrinksOnRightClick)
    }

    func testRoundTripReplacesSettingsAndSkipsWindowKeys() throws {
        let (source, sourceName) = makeDefaults()
        source.set("dark", forKey: "appTheme")
        source.set(["display-1": 2.0], forKey: "displaySizes")
        source.set("{0, 0, 10, 10}", forKey: "NSWindow Frame preferences")
        source.set(Date(), forKey: "lastUpdateCheck")
        source.set(HoldKeys([.control, .option]).rawValue, forKey: "highlightLaserKeys")
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: true)

        let (target, targetName) = makeDefaults()
        target.set("light", forKey: "appTheme")
        target.set(true, forKey: "perAppColors")
        let launchAtLogin = try SettingsBackup(defaults: target, domain: targetName).restore(from: data)

        XCTAssertEqual(launchAtLogin, true)
        XCTAssertEqual(target.integer(forKey: "highlightLaserKeys"), HoldKeys([.control, .option]).rawValue)

        XCTAssertEqual(target.string(forKey: "appTheme"), "dark")
        XCTAssertEqual(target.dictionary(forKey: "displaySizes") as? [String: Double], ["display-1": 2.0])
        XCTAssertNil(target.object(forKey: "perAppColors"))
        XCTAssertNil(target.object(forKey: "NSWindow Frame preferences"))
        XCTAssertNil(target.object(forKey: "lastUpdateCheck"))
    }

    func testRejectsOtherFiles() {
        let (defaults, name) = makeDefaults()
        let data = try! PropertyListSerialization.data(fromPropertyList: ["appTheme": "dark"], format: .xml, options: 0)
        XCTAssertThrowsError(try SettingsBackup(defaults: defaults, domain: name).restore(from: data))
    }

    func testOlderFilesLeaveOpenAtLoginAlone() throws {
        let (defaults, name) = makeDefaults()
        let file: [String: Any] = ["format": "pointer-colors-settings", "version": 1, "settings": ["appTheme": "dark"]]
        let data = try PropertyListSerialization.data(fromPropertyList: file, format: .xml, options: 0)
        XCTAssertNil(try SettingsBackup(defaults: defaults, domain: name).restore(from: data))
    }
}
