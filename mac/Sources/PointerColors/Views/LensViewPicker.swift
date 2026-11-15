import SwiftUI

/// Every choice of what the lens shows as a card, its map outlining the part it magnifies.
struct LensViewPicker: View {
    @Binding var selection: LensView
    let zoom: MagicMouseZoom

    var body: some View {
        LensMapCardGrid {
            ForEach(LensView.allCases) { option in
                LensMapCard(title: option.title, summary: option.summary, upsides: option.upsides, downsides: option.downsides,
                            isDefault: option == .centred, isSelected: selection == option,
                            map: LensPlacementMap(zoom, placement: zoom.lensPlacement, view: option, outlinesArea: true)) {
                    selection = option
                }
            }
        }
    }
}
