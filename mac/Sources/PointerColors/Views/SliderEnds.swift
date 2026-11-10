import SwiftUI

/// The pictures at the two ends of a slider, saying what moving it does.
enum SliderEnds {
    /// A length of time, in seconds. Laid out as macOS lays out speed: the tortoise, the longest
    /// time, on the left and the hare, the shortest, on the right, so the slider runs backwards.
    case time
    /// Small to large.
    case size
    /// A thin line to a thick one.
    case width
    /// Faint to solid.
    case opacity
    /// Dim to bright.
    case brightness
    /// Close together to far apart.
    case spread
    /// One ring to many.
    case count

    /// The slider runs from its largest value on the left to its smallest on the right.
    var isReversed: Bool { self == .time }

    var low: SliderEnd {
        switch self {
        case .time: SliderEnd("tortoise.fill")
        case .size: SliderEnd("circle", scale: .small)
        case .width: SliderEnd("line.diagonal", weight: .ultraLight)
        case .opacity: SliderEnd("circle.dotted")
        case .brightness: SliderEnd("sun.min")
        case .spread: SliderEnd("arrow.right.and.line.vertical.and.arrow.left")
        case .count: SliderEnd("circle")
        }
    }

    var high: SliderEnd {
        switch self {
        case .time: SliderEnd("hare.fill")
        case .size: SliderEnd("circle", scale: .large)
        case .width: SliderEnd("line.diagonal", weight: .black)
        case .opacity: SliderEnd("circle.fill")
        case .brightness: SliderEnd("sun.max.fill")
        case .spread: SliderEnd("arrow.left.and.line.vertical.and.arrow.right")
        case .count: SliderEnd("target")
        }
    }
}

/// One end's symbol, drawn small, large, thin or heavy.
struct SliderEnd {
    let symbol: String
    var scale = Image.Scale.medium
    var weight = Font.Weight.regular

    init(_ symbol: String, scale: Image.Scale = .medium, weight: Font.Weight = .regular) {
        (self.symbol, self.scale, self.weight) = (symbol, scale, weight)
    }

    var image: some View {
        Image(systemName: symbol)
            .imageScale(scale)
            .fontWeight(weight)
            .foregroundStyle(.secondary)
            .frame(width: 18)
            .accessibilityHidden(true)
    }
}
