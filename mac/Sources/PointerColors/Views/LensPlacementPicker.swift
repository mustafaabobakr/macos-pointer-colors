import SwiftUI

/// Every lens placement as a card, with a map to try it on.
struct LensPlacementPicker: View {
    @Binding var selection: LensPlacement
    let zoom: MagicMouseZoom

    var body: some View {
        LensMapCardGrid {
            ForEach(LensPlacement.allCases) { option in
                LensMapCard(title: option.title, summary: option.summary, upsides: option.upsides, downsides: option.downsides,
                            isDefault: option == .onPointer, isSelected: selection == option,
                            map: LensPlacementMap(zoom, placement: option, view: zoom.lensView, outlinesArea: false)) {
                    selection = option
                }
            }
        }
    }
}

extension LensPlacementMap {
    /// A map with the zoom's lens size, shape, amount and Pointer spot.
    @MainActor
    init(_ zoom: MagicMouseZoom, placement: LensPlacement, view: LensView, outlinesArea: Bool) {
        self.init(placement: placement, lens: zoom.lensShape.size(width: zoom.lensSize), shape: zoom.lensShape,
                  amount: zoom.amount, view: view, spot: zoom.lensViewSpot, outlinesArea: outlinesArea)
    }
}
