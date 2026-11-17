/// Each pulse style's own settings, so its card can tell whether any has moved from its default
/// and put them all back. Size is shared by every style and stays as it is; the color, outline
/// and Length that Ring and Ripple share belong to both.
@MainActor
extension PointerHighlight {
    /// Whether any of `style`'s own settings differs from its default.
    func isChanged(_ style: PulseStyle) -> Bool {
        Self.settings(of: style).contains { $0.isChanged(self) }
    }

    /// Puts `style`'s own settings back to their defaults.
    func reset(_ style: PulseStyle) {
        Self.settings(of: style).forEach { $0.reset(self) }
    }

    private static func settings(of style: PulseStyle) -> [StyleSetting] {
        switch style {
        case .ring: ringAndRippleShared + [setting(\.pulseLineWidth), setting(\.pulseOpacity), setting(\.pulseGrowth)]
        case .ripple: ringAndRippleShared + [setting(\.rippleWaves), setting(\.rippleSpacing), setting(\.rippleLineWidth),
                                             setting(\.rippleOpacity), setting(\.rippleGrowth)]
        case .frost: [setting(\.frostFlash), setting(\.frostShards), setting(\.frostColorSource), setting(\.frostColor),
                      setting(\.frostDuration), setting(\.frostGrowth)]
        case .bokeh: [setting(\.bokehSpeed), setting(\.bokehBlur), setting(\.bokehColorSource), setting(\.bokehColor),
                      setting(\.bokehColorLook), setting(\.bokehShapeChoice), setting(\.bokehCustomShapes)]
        }
    }

    private static var ringAndRippleShared: [StyleSetting] {
        [setting(\.pulseUsesPairColor), setting(\.pulseColor), setting(\.pulseOutlined), setting(\.pulseOutlineWidth),
         setting(\.pulseDuration)]
    }

    private static func setting<Value: Equatable>(_ key: ReferenceWritableKeyPath<PointerHighlight, Value>) -> StyleSetting {
        StyleSetting(isChanged: { $0[keyPath: key] != factory[keyPath: key] },
                     reset: { $0[keyPath: key] = factory[keyPath: key] })
    }
}

/// One setting of a style: whether it has moved from its default, and how to put it back.
@MainActor
private struct StyleSetting {
    let isChanged: (PointerHighlight) -> Bool
    let reset: (PointerHighlight) -> Void
}
