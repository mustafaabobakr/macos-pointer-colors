import AppKit
import SwiftUI

/// How large the app's own text and controls are. macOS has no Dynamic Type, so the app scales
/// its fonts and layout itself.
enum TextSize: String, CaseIterable, Identifiable {
    case automatic, standard, large, extraLarge, huge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .standard: return "Default"
        case .large: return "Large"
        case .extraLarge: return "Extra large"
        case .huge: return "Huge"
        }
    }

    private static let factors: [TextSize: CGFloat] = [.standard: 1, .large: 1.15, .extraLarge: 1.3, .huge: 1.5]

    /// Automatic picks Large on wide screens (5K-class, 2560 points and up) and Default otherwise.
    func factor(screenWidth: CGFloat) -> CGFloat {
        guard self == .automatic else { return Self.factors[self] ?? 1 }
        return screenWidth >= 2560 ? Self.factors[.large]! : 1
    }
}

/// The macOS default point sizes for the text styles the app uses.
enum AppFont: CGFloat {
    case caption2 = 10
    case tile = 10.5
    case caption = 11
    case callout = 12
    case body = 13
    case title3 = 15
    case title2 = 17
}

private struct AppTextScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var appTextScale: CGFloat {
        get { self[AppTextScaleKey.self] }
        set { self[AppTextScaleKey.self] = newValue }
    }
}

private struct AppFontModifier: ViewModifier {
    @Environment(\.appTextScale) private var scale
    let style: AppFont
    let weight: Font.Weight
    let monospacedDigits: Bool

    func body(content: Content) -> some View {
        let font = Font.system(size: style.rawValue * scale, weight: weight)
        return content.font(monospacedDigits ? font.monospacedDigit() : font)
    }
}

extension View {
    func appFont(_ style: AppFont, weight: Font.Weight = .regular, monospacedDigits: Bool = false) -> some View {
        modifier(AppFontModifier(style: style, weight: weight, monospacedDigits: monospacedDigits))
    }

    /// Sets the scale for everything inside, plus a scaled body font for controls that don't set one.
    func appTextScale(_ scale: CGFloat) -> some View {
        environment(\.appTextScale, scale)
            .font(.system(size: AppFont.body.rawValue * scale))
    }
}
