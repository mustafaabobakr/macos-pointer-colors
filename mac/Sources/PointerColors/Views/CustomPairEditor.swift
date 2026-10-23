import SwiftUI

/// Name plus outline and fill pickers, used for adding and editing custom pairs.
struct CustomPairEditor: View {
    let title: String
    let onSave: (String, RGBA, RGBA) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var outline: RGBA
    @State private var fill: RGBA

    init(title: String, initial: PointerPair?,
         onSave: @escaping (String, RGBA, RGBA) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial?.name ?? String(localized: "My pair"))
        _outline = State(initialValue: initial?.outline ?? RGBA(hex: "FFFFFF")!)
        _fill = State(initialValue: initial?.fill ?? RGBA(hex: "FF6FA8")!)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).appFont(.callout, weight: .semibold)
                Spacer()
                PointerGlyph(pair: preview).frame(height: 22)
            }
            TextField("Name", text: $name)
            InlineColorField(label: "Outline", color: $outline)
            InlineColorField(label: "Fill", color: $fill)
            ContrastWarning(pair: preview)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save pair") { onSave(name, outline, fill) }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    private var preview: PointerPair {
        PointerPair(id: "preview", name: name, outline: outline, fill: fill)
    }
}
