/// How a single-choice setting shows its options: side-by-side segments, or a dropdown menu.
enum SettingsChoiceStyle: Equatable {
    case segmented
    case menu

    /// The most options that still show as segments.
    static let mostSegments = 4

    /// Segments for up to `mostSegments` options, a dropdown for more.
    init(optionCount: Int) {
        self = optionCount <= Self.mostSegments ? .segmented : .menu
    }
}
