import Foundation

/// An array that keeps the elements it can read and skips the rest, so one bad entry in a saved
/// file doesn't lose everything around it.
struct Lossy<Element: Decodable>: Decodable {
    var elements: [Element] = []

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? container.decode(Skipped.self)
            }
        }
    }

    /// Reads past an entry that isn't an `Element`, whatever it is, so the loop always moves on.
    private struct Skipped: Decodable {
        init(from decoder: Decoder) {}
    }
}
