/// The symbols at a slider's two ends, and whether it runs backwards (largest value on the left).
/// `SliderEnds` names the common pairs; these are the ones only one place uses.
struct SliderIcons {
    let low: SliderEnd
    let high: SliderEnd
    var isReversed = false

    /// Slow to fast, smallest value on the left.
    static let speed = SliderIcons(low: SliderEnd("tortoise.fill"), high: SliderEnd("hare.fill"))
    /// The pointer drawn smaller to larger.
    static let pointerSize = SliderIcons(low: SliderEnd("textformat.size.smaller"), high: SliderEnd("textformat.size.larger"))
}

extension SliderEnds {
    var icons: SliderIcons { SliderIcons(low: low, high: high, isReversed: isReversed) }
}
