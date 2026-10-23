import SwiftUI

/// Name plus outline and fill pickers, used for adding and editing custom pairs.
struct CustomPairEditor: View {
    let title: String
    let onSave: (String, RGBA, RGBA) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var outline: Color
    @State private var fill: Color

    init(title: String, initial: PointerPair?,
         onSave: @escaping (String, RGBA, RGBA) -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: initial?.name ?? String(localized: "My pair"))
        _outline = State(initialValue: initial?.outline.color ?? .white)
        _fill = State(initialValue: initial?.fill.color ?? Color(red: 1, green: 0.435, blue: 0.659))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).appFont(.callout, weight: .semibold)
                Spacer()
                PointerGlyph(pair: preview).frame(height: 22)
            }
            TextField("Name", text: $name)
            HStack(spacing: 16) {
                ColorPicker(selection: $outline, supportsOpacity: false) {
                    Text("Outline \(RGBA(outline).hex)").appFont(.caption, monospacedDigits: true)
                }
                ColorPicker(selection: $fill, supportsOpacity: false) {
                    Text("Fill \(RGBA(fill).hex)").appFont(.caption, monospacedDigits: true)
                }
            }
            ContrastWarning(pair: preview)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save pair") { onSave(name, RGBA(outline), RGBA(fill)) }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
    }

    private var preview: PointerPair {
        PointerPair(id: "preview", name: name, outline: RGBA(outline), fill: RGBA(fill))
    }
}
