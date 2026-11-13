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
                       ["com.apple.Safari", "com.google.Chrome", "com.apple.Preview", "com.apple.Photos"])
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
