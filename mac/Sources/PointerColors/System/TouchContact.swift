import Foundation

/// One finger on the Magic Mouse, read from MultitouchSupport's finger records. The layout isn't
/// Apple's documented API; it was checked against 1,435 logged touches (positions 0–1, sizes 0–1.4).
nonisolated struct TouchContact: Sendable {
    /// Position on the mouse's surface, 0–1 from left to right and back to front.
    var x: Float = 0
    var y: Float = 0
    /// How much of the surface the contact covers.
    var size: Float = 0
    /// The contact ellipse's long and short axes.
    var major: Float = 0
    var minor: Float = 0

    /// Bytes per finger record, and where its fields sit in it.
    private static let stride = 96
    private static let xOffset = 32, yOffset = 36, sizeOffset = 48, majorOffset = 60, minorOffset = 64

    /// The biggest contact in a frame: a fingertip tap is big, a light graze small.
    static func largestSize(_ contacts: [TouchContact]) -> Float { contacts.map(\.size).max() ?? 0 }

    static func read(_ data: UnsafeMutableRawPointer?, count: Int) -> [TouchContact] {
        guard let data, count > 0 else { return [] }
        return (0..<min(count, 5)).map { index in
            let base = UnsafeRawPointer(data) + index * stride
            func float(_ offset: Int) -> Float { base.loadUnaligned(fromByteOffset: offset, as: Float.self) }
            return TouchContact(x: float(xOffset), y: float(yOffset), size: float(sizeOffset),
                               major: float(majorOffset), minor: float(minorOffset))
        }
    }
}
