import AppKit
import SwiftUI

/// Which of the app icon's designs the Dock shows. Follow System leaves it to System Settings ›
/// Appearance › Icon & widget style; Default and Dark pin one while the app runs. Finder always
/// follows the system.
enum AppIconStyle: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return String(localized: "Follow System")
        case .light: return String(localized: "Default")
        case .dark: return String(localized: "Dark")
        }
    }

    /// The flat icon the build makes for this design; nil for Follow System, or a build without it.
    var image: NSImage? {
        let name: String? = switch self {
        case .system: nil
        case .light: "AppIcon"
        case .dark: "AppIconDark"
        }
        return name.flatMap { Bundle.main.url(forResource: $0, withExtension: "icns") }.flatMap(NSImage.init(contentsOf:))
    }

    static var saved: AppIconStyle {
        UserDefaults.standard.string(forKey: "appIconStyle").flatMap(AppIconStyle.init(rawValue:)) ?? .system
    }

    func save() { UserDefaults.standard.set(rawValue, forKey: "appIconStyle") }

    /// Shows this design in the Dock. Nil puts back the system's own choice.
    @MainActor func apply() {
        // A feature clip sets its own icon.
        guard !ScreenshotRenderer.isRendering else { return }
        NSApp.applicationIconImage = image
    }
}

/// Follow System, Default and Dark as icon pictures, the chosen one outlined.
struct AppIconPicker: View {
    @Binding var selection: AppIconStyle
    @Environment(\.appTextScale) private var scale

    var body: some View {
        HStack(spacing: 14 * scale) {
            ForEach(AppIconStyle.allCases) { style in
                Button { selection = style } label: {
                    VStack(spacing: 6 * scale) {
                        preview(style)
                            .frame(width: 56 * scale, height: 56 * scale)
                            .padding(5 * scale)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                                    .strokeBorder(selection == style ? Color.accentColor : .clear, lineWidth: 2.5)
                            }
                        Text(style.title)
                            .appFont(.callout, weight: selection == style ? .semibold : .regular)
                            .foregroundStyle(selection == style ? Color.accentColor : .primary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(style.title)
                .accessibilityAddTraits(selection == style ? .isSelected : [])
            }
        }
    }

    /// Follow System shows Default and Dark split on the diagonal, like the theme's System.
    @ViewBuilder private func preview(_ style: AppIconStyle) -> some View {
        if style == .system {
            icon(.light).overlay { icon(.dark).clipShape(LowerRightHalf()) }
        } else {
            icon(style)
        }
    }

    @ViewBuilder private func icon(_ style: AppIconStyle) -> some View {
        if let image = style.image {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
        }
    }
}

/// The lower-right half of a rectangle.
private struct LowerRightHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
