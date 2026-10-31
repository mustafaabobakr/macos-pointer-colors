import SwiftUI

/// A menu section: a small heading, with an optional control on its right, over a rounded card.
/// The card is a soft wash with a hairline edge rather than glass, which wouldn't stand out on
/// the menu's own glass.
struct MenuCard<Accessory: View, Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content
    @Environment(\.appTextScale) private var scale

    init(_ title: LocalizedStringKey? = nil, @ViewBuilder accessory: () -> Accessory,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
        VStack(alignment: .leading, spacing: 6 * scale) {
            if let title {
                HStack {
                    Text(title)
                        .appFont(.caption2, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    accessory
                }
                .padding(.horizontal, 4 * scale)
            }
            VStack(alignment: .leading, spacing: 8 * scale) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10 * scale)
                .background(.quaternary.opacity(0.5), in: shape)
                .overlay { shape.strokeBorder(.separator) }
        }
    }
}

extension MenuCard where Accessory == EmptyView {
    init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, accessory: { EmptyView() }, content: content)
    }
}
