import SwiftUI

/// A small orange note when a pair is hard to spot; shows nothing otherwise.
struct ContrastWarning: View {
    let pair: PointerPair

    var body: some View {
        if let warning = PairVisibility(pair).warning {
            Label(warning, systemImage: "exclamationmark.triangle")
                .appFont(.caption)
                .foregroundStyle(.orange)
                .help("Neither the outline nor the fill reaches 3:1 contrast against that background.")
        }
    }
}
