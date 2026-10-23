import SwiftUI

/// The pair drawn over four everyday backgrounds, the same set as the website.
struct VisibilityPreviews: View {
    let pair: PointerPair
    let pointerScale: Double
    @Environment(\.appTextScale) private var scale

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PREVIEW").appFont(.caption2, weight: .semibold).foregroundStyle(.secondary)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(PreviewBackground.allCases) { background in
                    tile(background)
                }
            }
        }
    }

    private func tile(_ background: PreviewBackground) -> some View {
        ZStack(alignment: .bottomLeading) {
            background.fill
            PointerGlyph(pair: pair, lineWidth: 1.6)
                .frame(height: (14 + 4 * pointerScale) * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(background.title)
                .appFont(.caption2, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(.black.opacity(0.45)))
                .padding(4)
        }
        .frame(height: 56 * scale)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(pair.name) on \(background.title)")
    }
}

enum PreviewBackground: String, CaseIterable, Identifiable {
    case lightPage, darkApp, photo, spreadsheet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lightPage: return String(localized: "Light page")
        case .darkApp: return String(localized: "Dark app")
        case .photo: return String(localized: "Photo")
        case .spreadsheet: return String(localized: "Spreadsheet")
        }
    }

    @ViewBuilder var fill: some View {
        switch self {
        case .lightPage: Color.white
        case .darkApp: Color(red: 0.11, green: 0.11, blue: 0.118)
        case .photo: PhotoBackground()
        case .spreadsheet: SpreadsheetBackground()
        }
    }
}

private struct PhotoBackground: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.184, green: 0.42, blue: 0.31), location: 0),
                .init(color: Color(red: 0.788, green: 0.659, blue: 0.416), location: 0.6),
                .init(color: Color(red: 0.525, green: 0.725, blue: 0.847), location: 1),
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

private struct SpreadsheetBackground: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            var y: CGFloat = 12
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                             with: .color(Color(red: 0.855, green: 0.867, blue: 0.89)))
                y += 13
            }
        }
    }
}
