/// The color of the outline around Smart zoom's lens.
enum LensBorder: String, CaseIterable, Identifiable {
    case white
    /// The brighter of the pointer pair's colors, as the ring, pulse and laser use.
    case pair
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .white: String(localized: "White")
        case .pair: String(localized: "Pointer pair")
        case .custom: String(localized: "Custom")
        }
    }
}
