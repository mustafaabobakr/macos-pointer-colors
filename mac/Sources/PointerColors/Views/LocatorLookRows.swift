import SwiftUI

/// The pointer locator's ring and timing, under its switch: a live picture of the ring, then
/// how long it takes, how large it starts and ends, how thick it is, and how quick the presses are.
struct LocatorLookRows: View {
    @Bindable var locator: PointerLocator

    var body: some View {
        LocatorPreview(look: locator.look, pair: locator.currentPair, pointerScale: locator.currentPointerScale)
        ValueSlider(title: String(localized: "Animation length"), symbol: "timer", value: $locator.duration,
                    range: LocatorLook.durationRange, format: "%.1f s", step: 0.1, ends: .time)
        ValueSlider(title: String(localized: "Start size"), symbol: "circle.dashed", value: $locator.startRadius,
                    range: LocatorLook.startRadiusRange, format: "%.0f pt", step: 5, ends: .size)
        ValueSlider(title: String(localized: "End size"), symbol: "scope", value: $locator.endSize,
                    range: LocatorLook.endSizeRange, format: "%.1f×", step: 0.1, ends: .size)
        ValueSlider(title: String(localized: "Line width"), symbol: "lineweight", value: $locator.lineWidth,
                    range: LocatorLook.lineWidthRange, format: "%.1f×", step: 0.1, ends: .width)
        ValueSlider(title: String(localized: "Time between presses"), symbol: "keyboard.badge.ellipsis",
                    value: $locator.pressGap, range: DoubleTap.gapRange, format: "%.2f s", step: 0.05, ends: .time)
    }
}
