import SwiftUI

/// System, Light and Dark as small window pictures, the chosen one outlined.
struct ThemePicker: View {
    @Binding var selection: AppTheme
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 12 * scale) {
            ForEach(AppTheme.allCases) { theme in
                Button { selection = theme } label: {
                    VStack(spacing: 6 * scale) {
                        ThemeThumbnail(theme: theme)
                            .frame(height: 64 * scale)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8 * scale)
                                    .strokeBorder(selection == theme ? Color.accentColor : Color.primary.opacity(0.12),
                                                  lineWidth: selection == theme ? 2.5 : 1)
                            }
                        Text(theme.title)
                            .appFont(.callout, weight: selection == theme ? .semibold : .regular)
                            .foregroundStyle(selection == theme ? Color.accentColor : .primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(theme.title)
                .accessibilityAddTraits(selection == theme ? .isSelected : [])
            }
        }
    }
}

/// A tiny window in the theme's colors; System is split light and dark on the diagonal.
private struct ThemeThumbnail: View {
    let theme: AppTheme
    @Environment(\.appTextScale) private var scale

    var body: some View {
        switch theme {
        case .light: window(dark: false)
        case .dark: window(dark: true)
        case .system:
            window(dark: false).overlay {
                window(dark: true).clipShape(Diagonal())
            }
        }
    }

    private func window(dark: Bool) -> some View {
        let background = dark ? Color(white: 0.17) : Color(white: 0.97)
        let bar = dark ? Color(white: 0.24) : Color(white: 0.88)
        let line = dark ? Color(white: 0.38) : Color(white: 0.78)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3 * scale) {
                ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 5 * scale) }
            }
            .padding(5 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bar)
            HStack(alignment: .top, spacing: 6 * scale) {
                RoundedRectangle(cornerRadius: 2).fill(bar).frame(width: 18 * scale)
                VStack(alignment: .leading, spacing: 4 * scale) {
                    ForEach([34.0, 22, 28], id: \.self) { width in
                        Capsule().fill(line).frame(width: width * scale, height: 3 * scale)
                    }
                }
            }
            .padding(5 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8 * scale))
    }
}

/// The lower-right half of a rectangle.
private struct Diagonal: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
