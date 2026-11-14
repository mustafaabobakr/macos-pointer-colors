import IOSurface
import CoreVideo
import XCTest
@testable import PointerColors

final class DoublePressTests: XCTestCase {
    func testTwoQuickPressesAreADoublePress() {
        var presses = DoublePress(window: 0.4)
        XCTAssertFalse(presses.press(at: 0))
        XCTAssertTrue(presses.press(at: 0.3))
    }

    func testSlowPressesAreNot() {
        var presses = DoublePress(window: 0.4)
        XCTAssertFalse(presses.press(at: 0))
        XCTAssertFalse(presses.press(at: 0.5))
        XCTAssertTrue(presses.press(at: 0.8))
    }

    /// A third quick press starts a new double press rather than zooming back out at once.
    func testThirdQuickPressStartsAfresh() {
        var presses = DoublePress(window: 0.4)
        XCTAssertFalse(presses.press(at: 0))
        XCTAssertTrue(presses.press(at: 0.2))
        XCTAssertFalse(presses.press(at: 0.4))
        XCTAssertTrue(presses.press(at: 0.6))
    }
}

final class MagicMouseDoubleTapTests: XCTestCase {
    /// Touches one finger at `time` for `length` seconds. True when lifting it finishes a double tap.
    private func tap(_ taps: inout MagicMouseDoubleTap, at time: TimeInterval, length: TimeInterval = 0.1, fingers: Int = 1) -> Bool {
        _ = taps.frame(fingers: fingers, at: time)
        _ = taps.frame(fingers: fingers, at: time + length / 2)
        return taps.frame(fingers: 0, at: time + length)
    }

    /// The timing the Magic Mouse gave in a real test: 0.1 s taps, about 0.2 s apart.
    func testTwoQuickTapsZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 80.189, length: 0.12))
        XCTAssertTrue(tap(&taps, at: 80.384, length: 0.135))
    }

    func testRestingFingerIsNotATap() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0, length: 1.2))
        XCTAssertFalse(tap(&taps, at: 1.3))
    }

    func testTwoFingersAreNotATap() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0, fingers: 2))
        XCTAssertFalse(tap(&taps, at: 0.2, fingers: 2))
    }

    func testSlowTapsDontZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0))
        XCTAssertFalse(tap(&taps, at: 1))
    }

    /// Two quick scroll flicks look like taps, but each one scrolls, so they never zoom.
    func testScrollFlicksDontZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        for start in [0.0, 0.25] {
            _ = taps.frame(fingers: 1, at: start)
            taps.interrupt(at: start + 0.04)
            XCTAssertFalse(taps.frame(fingers: 0, at: start + 0.1))
        }
    }

    /// The momentum after a flick ends a tap waiting for its second, so a tap right after doesn't pair with it.
    func testScrollEndsAWaitingTap() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0))
        taps.interrupt(at: 0.15)
        XCTAssertFalse(tap(&taps, at: 0.3))
    }

    /// A quick click touches the mouse too, so it mustn't count as a tap.
    func testClickIsNotATap() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        _ = taps.frame(fingers: 1, at: 0)
        taps.interrupt(at: 0.03)
        XCTAssertFalse(taps.frame(fingers: 0, at: 0.1))
        XCTAssertFalse(tap(&taps, at: 0.25))
        XCTAssertTrue(tap(&taps, at: 0.45))
    }

    /// Touches one finger at `time` while the pointer moves `travel` points to the right.
    private func movingTap(_ taps: inout MagicMouseDoubleTap, at time: TimeInterval, length: TimeInterval, travel: CGFloat) -> Bool {
        _ = taps.frame(fingers: 1, at: time, pointer: .zero)
        _ = taps.frame(fingers: 1, at: time + length / 2, pointer: CGPoint(x: travel / 2, y: 0))
        return taps.frame(fingers: 0, at: time + length, pointer: CGPoint(x: travel, y: 0))
    }

    /// From the diagnostics log: a finger brushing the mouse as it was moved (0.21 s with 42.5 pt
    /// of pointer travel, then 0.18 s with 55.8 pt) zoomed in by itself.
    func testBrushingTheMouseWhileMovingItDoesntZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(movingTap(&taps, at: 0, length: 0.21, travel: 42.5))
        XCTAssertFalse(movingTap(&taps, at: 0.25, length: 0.178, travel: 55.8))
    }

    /// Real double taps in the log nudged the pointer up to about 5 points, and still zoom.
    func testATapThatNudgesThePointerStillZooms() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(movingTap(&taps, at: 0, length: 0.12, travel: 4.9))
        XCTAssertTrue(movingTap(&taps, at: 0.25, length: 0.122, travel: 1))
    }

    /// From the diagnostics log: a 0.017 s flicker of contact, then a real tap, zoomed by itself.
    func testAContactFlickerIsNotATap() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0, length: 0.017))
        XCTAssertFalse(tap(&taps, at: 0.06, length: 0.135))
        XCTAssertFalse(tap(&taps, at: 0.5, length: 0.062))
        XCTAssertTrue(tap(&taps, at: 0.75, length: 0.1))
    }

    /// From the diagnostics log: the finger settling after the mouse was moved flickered for 0.03 s,
    /// then two still 0.167 s touches 0.06 s later zoomed by themselves.
    func testTwoTapsRightAfterAFlickerDontZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0, length: 0.03))
        XCTAssertFalse(tap(&taps, at: 0.09, length: 0.167))
        XCTAssertFalse(tap(&taps, at: 0.315, length: 0.167))
    }

    /// From the diagnostics log: a hand settling on the mouse after moving it touched for 0.181 s,
    /// then 0.197 s, both nearly still, and zoomed by itself.
    func testTwoLongStillTouchesDontZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(movingTap(&taps, at: 0, length: 0.181, travel: 6.5))
        XCTAssertFalse(movingTap(&taps, at: 0.285, length: 0.197, travel: 0.8))
    }

    private func sizedTap(_ taps: inout MagicMouseDoubleTap, at time: TimeInterval, length: TimeInterval, size: Float) -> Bool {
        _ = taps.frame(fingers: 1, at: time, size: size)
        _ = taps.frame(fingers: 1, at: time + length / 2, size: size)
        return taps.frame(fingers: 0, at: time + length, size: 0)
    }

    /// From the diagnostics log: 0.10 s after a two-finger touch, a finger grazed the side of the
    /// mouse twice (contacts 0.12 and 0.25) and zoomed by itself.
    func testLightGrazesDontZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(sizedTap(&taps, at: 0, length: 0.106, size: 0.12))
        XCTAssertFalse(sizedTap(&taps, at: 0.134, length: 0.169, size: 0.25))
    }

    /// The double tap that zoomed back out right after: fingertip contacts of 0.88.
    func testFingertipTapsZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(sizedTap(&taps, at: 0, length: 0.139, size: 0.88))
        XCTAssertTrue(sizedTap(&taps, at: 0.212, length: 0.122, size: 0.88))
    }

    /// With no wait after a flicker, the logged grip change zooms again.
    func testNoWaitAfterAFlickerLetsTheLoggedPairZoom() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        taps.limits.settleAfterFlicker = 0
        XCTAssertFalse(tap(&taps, at: 0, length: 0.03))
        XCTAssertFalse(tap(&taps, at: 0.09, length: 0.167))
        XCTAssertTrue(tap(&taps, at: 0.315, length: 0.167))
    }

    /// The closest real double tap in the log came 0.46 s after a flicker, and still zooms.
    func testADoubleTapWellAfterAFlickerZooms() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(tap(&taps, at: 0, length: 0.045))
        XCTAssertFalse(tap(&taps, at: 0.51, length: 0.12))
        XCTAssertTrue(tap(&taps, at: 0.7, length: 0.12))
    }

    /// Loosened limits let the logged flicker and brush through again.
    func testLoosenedLimitsAcceptWhatTheDefaultsRefuse() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        taps.limits = TapLimits(shortest: 0, longest: 0.25, farthestTravel: 100, settleAfterFlicker: 0, lightest: 0)
        XCTAssertFalse(tap(&taps, at: 0, length: 0.017))
        XCTAssertTrue(movingTap(&taps, at: 0.06, length: 0.178, travel: 55.8))
    }

    /// One moving touch ruins only itself: the next two still taps zoom.
    func testAMovingTouchDoesntPairWithAStillTap() {
        var taps = MagicMouseDoubleTap(window: 0.5)
        XCTAssertFalse(movingTap(&taps, at: 0, length: 0.1, travel: 30))
        XCTAssertFalse(tap(&taps, at: 0.2))
        XCTAssertTrue(tap(&taps, at: 0.4))
    }
}

final class ZoomGeometryTests: XCTestCase {
    /// The spot under the pointer is the spot shown under it.
    func testWholeScreenKeepsThePointersSpot() {
        let pointer = CGPoint(x: 0.3, y: 0.8)
        let rect = ZoomGeometry.wholeScreen(pointer: pointer, amount: 2)
        XCTAssertEqual(rect.width, 0.5, accuracy: 1e-9)
        XCTAssertEqual(rect.minX + pointer.x * rect.width, pointer.x, accuracy: 1e-9)
        XCTAssertEqual(rect.minY + pointer.y * rect.height, pointer.y, accuracy: 1e-9)
    }

    func testLensIsCentredOnThePointer() {
        let rect = ZoomGeometry.lens(pointer: CGPoint(x: 0.5, y: 0.5), amount: 2, lens: CGSize(width: 0.2, height: 0.4))
        XCTAssertEqual(rect.midX, 0.5, accuracy: 1e-9)
        XCTAssertEqual(rect.midY, 0.5, accuracy: 1e-9)
        XCTAssertEqual(rect.width, 0.1, accuracy: 1e-9)
        XCTAssertEqual(rect.height, 0.2, accuracy: 1e-9)
    }

    func testLayerRectStartsAtTheBottom() {
        let rect = ZoomGeometry.layerRect(CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2))
        XCTAssertEqual(rect.minY, 0.7, accuracy: 1e-9)
    }
}

@MainActor
final class MagicMouseZoomSettingsTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let name = "MagicMouseZoomSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testFreshInstallIsOffAt2xWholeScreen() {
        let zoom = MagicMouseZoom(defaults: makeDefaults())
        XCTAssertFalse(zoom.isOn)
        XCTAssertEqual(zoom.style, .wholeScreen)
        XCTAssertEqual(zoom.amount, 2)
        XCTAssertEqual(zoom.lensSize, 300)
        XCTAssertEqual(zoom.tapWindow, MagicMouseZoom.defaultTapWindow)
        XCTAssertEqual(zoom.animationLength, 0.25)
        XCTAssertTrue(zoom.showsInScreenShare)
    }

    func testSettingsAreSaved() {
        let defaults = makeDefaults()
        let zoom = MagicMouseZoom(defaults: defaults)
        zoom.style = .lens
        zoom.amount = 3.5
        zoom.lensSize = 420
        zoom.tapWindow = 0.6
        zoom.showsInScreenShare = false
        let reloaded = MagicMouseZoom(defaults: defaults)
        XCTAssertFalse(reloaded.showsInScreenShare)
        XCTAssertEqual(reloaded.style, .lens)
        XCTAssertEqual(reloaded.amount, 3.5)
        XCTAssertEqual(reloaded.lensSize, 420)
        XCTAssertEqual(reloaded.tapWindow, 0.6)
    }

    /// A backup from elsewhere could hold a value outside the slider.
    func testOutOfRangeValuesAreClamped() {
        let defaults = makeDefaults()
        defaults.set(9.0, forKey: "magicMouseZoomAmount")
        defaults.set(50.0, forKey: "magicMouseZoomLensSize")
        let zoom = MagicMouseZoom(defaults: defaults)
        XCTAssertEqual(zoom.amount, 5)
        XCTAssertEqual(zoom.lensSize, 150)
    }
}

final class ZoomAnimationTests: XCTestCase {
    func testGrowsOverItsLength() {
        var animation = ZoomAnimation(length: 0.2)
        animation.target = 1
        animation.advance(by: 0.1)
        XCTAssertEqual(animation.progress, 0.5, accuracy: 1e-9)
        XCTAssertFalse(animation.isFinished)
        animation.advance(by: 0.2)
        XCTAssertEqual(animation.progress, 1)
        XCTAssertTrue(animation.isFinished)
    }

    func testShrinksBackFromWhereItIs() {
        var animation = ZoomAnimation(length: 0.2)
        animation.target = 1
        animation.advance(by: 0.15)
        animation.target = 0
        animation.advance(by: 0.1)
        XCTAssertEqual(animation.progress, 0.25, accuracy: 1e-9)
    }

    func testNoLengthJumps() {
        var animation = ZoomAnimation(length: 0)
        animation.target = 1
        animation.advance(by: 0)
        XCTAssertTrue(animation.isFinished)
        XCTAssertEqual(animation.eased, 1)
    }

    func testEasingStartsQuicklyAndSettles() {
        var animation = ZoomAnimation(length: 1)
        animation.target = 1
        animation.advance(by: 0.5)
        XCTAssertGreaterThan(animation.eased, 0.5)
    }
}

@MainActor
final class NativeZoomAppsTests: XCTestCase {
    private func makeZoom() -> (MagicMouseZoom, UserDefaults) {
        let name = "NativeZoomAppsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (MagicMouseZoom(defaults: defaults), defaults)
    }

    func testStartsWithThePickedApps() {
        let (zoom, _) = makeZoom()
        XCTAssertTrue(zoom.leavesNativeZoom)
        XCTAssertEqual(zoom.nativeZoomApps.map(\.bundleID),
                       ["com.apple.Safari", "com.google.Chrome", "com.brave.Browser", "com.apple.Preview", "com.apple.Photos"])
    }

    func testListedAppIsLeftToMacOS() {
        let (zoom, _) = makeZoom()
        XCTAssertTrue(zoom.leavesToMacOS("com.apple.Safari", isZoomed: false))
        XCTAssertFalse(zoom.leavesToMacOS("com.apple.finder", isZoomed: false))
        XCTAssertFalse(zoom.leavesToMacOS(nil, isZoomed: false))
    }

    /// Once Pointer Colors has zoomed in, a double tap over Safari still zooms it back out.
    func testOwnZoomAlwaysZoomsOut() {
        let (zoom, _) = makeZoom()
        XCTAssertFalse(zoom.leavesToMacOS("com.apple.Safari", isZoomed: true))
    }

    func testSwitchOffZoomsEverywhere() {
        let (zoom, _) = makeZoom()
        zoom.leavesNativeZoom = false
        XCTAssertFalse(zoom.leavesToMacOS("com.apple.Safari", isZoomed: false))
    }

    func testRemovedAppStaysRemoved() {
        let (zoom, defaults) = makeZoom()
        zoom.removeNativeZoomApp("com.apple.Photos")
        XCTAssertFalse(MagicMouseZoom(defaults: defaults).nativeZoomApps.contains { $0.bundleID == "com.apple.Photos" })
    }
}

final class StillZoomEdgeTests: XCTestCase {
    private let display = CGRect(x: 3840, y: 0, width: 3456, height: 2234)

    /// Pushed past the right edge, the pointer stops 10 points short of it.
    func testStopsTenPointsFromTheEdge() {
        let kept = ZoomGeometry.kept(CGPoint(x: 7400, y: -50), inside: display, margin: 10)
        XCTAssertEqual(kept, CGPoint(x: 7286, y: 10))
    }

    func testMovesFreelyInside() {
        let point = CGPoint(x: 5000, y: 1000)
        XCTAssertEqual(ZoomGeometry.kept(point, inside: display, margin: 10), point)
    }
}

@MainActor
final class ZoomMotionSettingsTests: XCTestCase {
    func testStaysByDefaultAndIsSaved() {
        let name = "ZoomMotionSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        let zoom = MagicMouseZoom(defaults: defaults)
        XCTAssertEqual(zoom.motion, .stays)
        zoom.motion = .follows
        XCTAssertEqual(MagicMouseZoom(defaults: defaults).motion, .follows)
    }
}

@MainActor
final class LensShapeTests: XCTestCase {
    func testRectangleByDefaultAndSaved() {
        let name = "LensShapeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        let zoom = MagicMouseZoom(defaults: defaults)
        XCTAssertEqual(zoom.lensShape, .rectangle)
        zoom.lensShape = .circle
        XCTAssertEqual(MagicMouseZoom(defaults: defaults).lensShape, .circle)
    }

    func testCornerRadius() {
        XCTAssertEqual(LensShape.square.cornerRadius(for: CGSize(width: 300, height: 300)), 0)
        XCTAssertEqual(LensShape.circle.cornerRadius(for: CGSize(width: 300, height: 300)), 150)
    }

    /// Rectangle comes first, so it's the first segment.
    func testRectangleIsFirstAnd16By9() {
        XCTAssertEqual(LensShape.allCases.first, .rectangle)
        XCTAssertEqual(LensShape.rectangle.size(width: 640), CGSize(width: 640, height: 360))
        XCTAssertEqual(LensShape.square.size(width: 640), CGSize(width: 640, height: 640))
    }
}

@MainActor
final class LensBorderTests: XCTestCase {
    private func makeZoom() -> (MagicMouseZoom, UserDefaults) {
        let name = "LensBorderTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (MagicMouseZoom(defaults: defaults), defaults)
    }

    func testWhiteByDefault() {
        let (zoom, _) = makeZoom()
        XCTAssertEqual(zoom.lensBorder, .white)
        XCTAssertEqual(zoom.borderColor, MagicMouseZoom.whiteBorder)
    }

    func testPairFollowsThePair() {
        let (zoom, _) = makeZoom()
        let green = RGBA(red: 0, green: 1, blue: 0)
        zoom.pairColor = { green }
        zoom.lensBorder = .pair
        XCTAssertEqual(zoom.borderColor, green)
    }

    func testCustomColorIsSaved() {
        let (zoom, defaults) = makeZoom()
        let pink = RGBA(red: 1, green: 0.2, blue: 0.6)
        zoom.lensBorder = .custom
        zoom.lensBorderColor = pink
        let reloaded = MagicMouseZoom(defaults: defaults)
        XCTAssertEqual(reloaded.lensBorder, .custom)
        XCTAssertEqual(reloaded.borderColor, pink)
    }
}

/// The ring and laser are left out of the zoom's capture, so they must draw above the zoom window.
@MainActor
final class ZoomWindowLevelTests: XCTestCase {
    func testZoomSitsUnderTheOverlays() {
        XCTAssertLessThan(ScreenZoom.level.rawValue, NSWindow.Level.screenSaver.rawValue)
    }
}

/// The laser's keys or a drawing hold a lens or following zoom still, when the setting allows it.
@MainActor
final class ZoomHoldForLaserTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let name = "ZoomHoldForLaserTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (defaults, name)
    }

    func testHoldsWhileDrawingByDefault() {
        let zoom = MagicMouseZoom(defaults: makeDefaults().0)
        XCTAssertTrue(zoom.holdsForLaser)
        zoom.laserHolds(true)
        XCTAssertTrue(zoom.isHeldForLaser)
        zoom.laserHolds(false)
        zoom.laserHolds(false)
        XCTAssertFalse(zoom.isHeldForLaser, "repeated ends are fine")
    }

    func testOffNeverHolds() {
        let zoom = MagicMouseZoom(defaults: makeDefaults().0)
        zoom.laserHolds(true)
        zoom.holdsForLaser = false
        XCTAssertFalse(zoom.isHeldForLaser, "turning it off lets go at once")
        zoom.laserHolds(true)
        XCTAssertFalse(zoom.isHeldForLaser)
    }

    func testTapLimitsStartAtTheLoggedDefaults() {
        let zoom = MagicMouseZoom(defaults: makeDefaults().0)
        XCTAssertEqual(zoom.shortestTap, 0.05)
        XCTAssertEqual(zoom.longestTap, 0.17)
        XCTAssertEqual(zoom.tapTravel, 10)
        XCTAssertEqual(zoom.flickerSettle, 0.3)
        XCTAssertEqual(zoom.lightestTap, 0.5)
        XCTAssertTrue(zoom.hasDefaultTapLimits)
    }

    func testTapLimitsAreSavedClampedAndReset() {
        let (defaults, _) = makeDefaults()
        let zoom = MagicMouseZoom(defaults: defaults)
        zoom.shortestTap = 0.03
        zoom.longestTap = 0.3
        zoom.tapTravel = 25
        zoom.flickerSettle = 0.5
        zoom.lightestTap = 0.3
        XCTAssertFalse(zoom.hasDefaultTapLimits)
        let reloaded = MagicMouseZoom(defaults: defaults)
        XCTAssertEqual(reloaded.shortestTap, 0.03)
        XCTAssertEqual(reloaded.longestTap, 0.3)
        XCTAssertEqual(reloaded.tapTravel, 25)
        XCTAssertEqual(reloaded.flickerSettle, 0.5)
        XCTAssertEqual(reloaded.lightestTap, 0.3, accuracy: 0.0001)
        reloaded.restoreTapLimits()
        XCTAssertTrue(MagicMouseZoom(defaults: defaults).hasDefaultTapLimits)
        defaults.set(5.0, forKey: "magicMouseZoomShortestTap")
        defaults.set(-3.0, forKey: "magicMouseZoomTapTravel")
        let clamped = MagicMouseZoom(defaults: defaults)
        XCTAssertEqual(clamped.shortestTap, MagicMouseZoom.shortestTapRange.upperBound)
        XCTAssertEqual(clamped.tapTravel, MagicMouseZoom.tapTravelRange.lowerBound)
    }

    func testDetectionStartsWithMacOSAndIsSaved() throws {
        let (source, sourceName) = makeDefaults()
        let zoom = MagicMouseZoom(defaults: source)
        XCTAssertEqual(zoom.tapDetection, .macOS)
        zoom.tapDetection = .both
        XCTAssertEqual(MagicMouseZoom(defaults: source).tapDetection, .both)
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)
        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        XCTAssertEqual(MagicMouseZoom(defaults: target).tapDetection, .both)
    }

    func testUpscalingStartsSmoothAndIsSaved() throws {
        let (source, sourceName) = makeDefaults()
        let zoom = MagicMouseZoom(defaults: source)
        XCTAssertEqual(zoom.upscaling, .smooth)
        zoom.upscaling = .sharper
        XCTAssertEqual(MagicMouseZoom(defaults: source).upscaling, .sharper)
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)
        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        XCTAssertEqual(MagicMouseZoom(defaults: target).upscaling, .sharper)
    }

    func testMacOSDetectionNeedsTheEventTap() {
        let zoom = MagicMouseZoom(defaults: makeDefaults().0)
        zoom.style = .lens
        zoom.isOn = true
        XCTAssertTrue(zoom.needsAccessibility)
        zoom.tapDetection = .pointerColors
        XCTAssertFalse(zoom.needsAccessibility)
        zoom.isOn = false
    }

    func testBackupCarriesTheTapLimits() throws {
        let (source, sourceName) = makeDefaults()
        let zoom = MagicMouseZoom(defaults: source)
        zoom.shortestTap = 0.02
        zoom.longestTap = 0.4
        zoom.tapTravel = 40
        zoom.flickerSettle = 0.6
        zoom.lightestTap = 0.8
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)
        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        let restored = MagicMouseZoom(defaults: target)
        XCTAssertEqual(restored.shortestTap, 0.02)
        XCTAssertEqual(restored.longestTap, 0.4)
        XCTAssertEqual(restored.tapTravel, 40)
        XCTAssertEqual(restored.flickerSettle, 0.6)
        XCTAssertEqual(restored.lightestTap, 0.8, accuracy: 0.0001)
    }

    func testBackupCarriesTheSetting() throws {
        let (source, sourceName) = makeDefaults()
        MagicMouseZoom(defaults: source).holdsForLaser = false
        let data = try SettingsBackup(defaults: source, domain: sourceName).export(launchAtLogin: false)
        let (target, targetName) = makeDefaults()
        try SettingsBackup(defaults: target, domain: targetName).restore(from: data)
        XCTAssertFalse(MagicMouseZoom(defaults: target).holdsForLaser)
    }
}

final class TapVotesTests: XCTestCase {
    func testMacOSOnlyZoomsOnMacOSAlone() {
        var votes = TapVotes(detection: .macOS)
        XCTAssertFalse(votes.own(at: 1))
        XCTAssertTrue(votes.macOS(at: 1))
    }

    func testPointerColorsOnlyIgnoresMacOS() {
        var votes = TapVotes(detection: .pointerColors)
        XCTAssertFalse(votes.macOS(at: 1))
        XCTAssertTrue(votes.own(at: 1))
    }

    /// From the probe: macOS's double tap came 11 ms before Pointer Colors' own.
    func testBothZoomsWhenTheyAgreeInEitherOrder() {
        var votes = TapVotes(detection: .both)
        XCTAssertFalse(votes.macOS(at: 28412.702))
        XCTAssertTrue(votes.own(at: 28412.713))
        XCTAssertFalse(votes.own(at: 30))
        XCTAssertTrue(votes.macOS(at: 30.05))
    }

    func testBothNeedsTheTwoCloseTogether() {
        var votes = TapVotes(detection: .both)
        XCTAssertFalse(votes.macOS(at: 1))
        XCTAssertFalse(votes.own(at: 1.5))
    }

    /// One agreement makes one zoom; a stray vote right after doesn't pair with it again.
    func testAnAgreementIsUsedUp() {
        var votes = TapVotes(detection: .both)
        XCTAssertFalse(votes.macOS(at: 1))
        XCTAssertTrue(votes.own(at: 1.01))
        XCTAssertFalse(votes.macOS(at: 1.05))
    }

    func testTheGestureEventTypeExists() {
        XCTAssertEqual(MagicMouseZoom.gestureEvent.rawValue, 29)
    }
}

@MainActor
final class ZoomSharpenerTests: XCTestCase {
    /// A capture whose top half is white and bottom half black.
    private func capture(width: Int = 64, height: Int = 64) -> IOSurfaceRef {
        let surface = IOSurfaceCreate([kIOSurfaceWidth: width, kIOSurfaceHeight: height, kIOSurfaceBytesPerElement: 4,
                                       kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA] as CFDictionary)!
        IOSurfaceLock(surface, [], nil)
        let base = IOSurfaceGetBaseAddress(surface).assumingMemoryBound(to: UInt8.self)
        let row = IOSurfaceGetBytesPerRow(surface)
        for y in 0..<height { memset(base + y * row, y < height / 2 ? 255 : 0, width * 4) }
        IOSurfaceUnlock(surface, [], nil)
        return surface
    }

    private func pixel(_ surface: IOSurfaceRef, x: Int, y: Int) -> UInt8 {
        IOSurfaceLock(surface, .readOnly, nil)
        defer { IOSurfaceUnlock(surface, .readOnly, nil) }
        let base = IOSurfaceGetBaseAddress(surface).assumingMemoryBound(to: UInt8.self)
        return base[y * IOSurfaceGetBytesPerRow(surface) + x * 4]
    }

    func testDrawsThePartAtTheAskedSize() throws {
        let sharpener = ZoomSharpener()
        let out = try XCTUnwrap(sharpener.picture(of: capture(), frame: 1, part: CGRect(x: 0, y: 0, width: 0.5, height: 0.5),
                                                  size: CGSize(width: 200, height: 100), sharpening: 0.5))
        XCTAssertEqual(IOSurfaceGetWidth(out), 200)
        XCTAssertEqual(IOSurfaceGetHeight(out), 100)
    }

    /// The part is counted from the top left, as the zoom counts it: the top quarter is white.
    func testKeepsTheTopAtTheTop() throws {
        let sharpener = ZoomSharpener()
        let top = try XCTUnwrap(sharpener.picture(of: capture(), frame: 1, part: CGRect(x: 0.25, y: 0, width: 0.5, height: 0.25),
                                                  size: CGSize(width: 64, height: 32), sharpening: 0.5))
        XCTAssertGreaterThan(pixel(top, x: 32, y: 16), 200)
        let bottom = try XCTUnwrap(sharpener.picture(of: capture(), frame: 2, part: CGRect(x: 0.25, y: 0.75, width: 0.5, height: 0.25),
                                                     size: CGSize(width: 64, height: 32), sharpening: 0.5))
        XCTAssertLessThan(pixel(bottom, x: 32, y: 16), 50)
    }

    func testTheSameJobIsntDrawnAgain() throws {
        let sharpener = ZoomSharpener()
        let surface = capture()
        let part = CGRect(x: 0, y: 0, width: 1, height: 1), size = CGSize(width: 64, height: 64)
        let first = sharpener.picture(of: surface, frame: 1, part: part, size: size, sharpening: 0.5)
        let again = sharpener.picture(of: surface, frame: 1, part: part, size: size, sharpening: 0.5)
        XCTAssertTrue(first === again)
        let next = sharpener.picture(of: surface, frame: 2, part: part, size: size, sharpening: 0.5)
        XCTAssertFalse(first === next)
    }
}

@MainActor
final class ZoomUpscalingSampleTests: XCTestCase {
    /// Each card's sample fills its frame in the display's pixels, and the choices look different.
    /// Each card's sample fills its frame in the display's pixels, and the choices look different.
    func testSamplesFillTheirFrameAndDiffer() throws {
        let size = CGSize(width: 160, height: 64)
        let pictures = try ZoomUpscaling.allCases.map {
            try XCTUnwrap(ZoomUpscalingSample.picture($0, size: size, amount: 2.5, scale: 2, dark: false))
        }
        for picture in pictures {
            XCTAssertEqual(picture.width, 320)
            XCTAssertEqual(picture.height, 128)
        }
        let bytes = pictures.map { $0.dataProvider?.data as Data? }
        XCTAssertNotEqual(bytes[0], bytes[1])
        XCTAssertNotEqual(bytes[1], bytes[2])
    }

    func testEveryChoiceSaysWhatItCosts() {
        for option in ZoomUpscaling.allCases {
            XCTAssertFalse(option.upsides.isEmpty)
            XCTAssertFalse(option.downsides.isEmpty)
        }
    }
}


final class HeldFrameTests: XCTestCase {
    /// The capture paints new frames into surfaces not in use, so a held one must count as in use.
    func testAHeldFrameIsInUseUntilLetGo() throws {
        let surface = try XCTUnwrap(IOSurfaceCreate([
            kIOSurfaceWidth: 8, kIOSurfaceHeight: 8, kIOSurfaceBytesPerElement: 4,
            kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA,
        ] as CFDictionary))
        XCTAssertFalse(IOSurfaceIsInUse(surface))
        var frame: HeldFrame? = HeldFrame(surface)
        XCTAssertTrue(IOSurfaceIsInUse(surface))
        XCTAssertEqual(frame?.surface, surface)
        frame = nil
        XCTAssertFalse(IOSurfaceIsInUse(surface))
    }
}
