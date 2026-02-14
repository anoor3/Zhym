import SwiftUI

enum ZhymPalette {
    static let night = Color(red: 4/255, green: 6/255, blue: 12/255)
    static let abyss = Color(red: 12/255, green: 15/255, blue: 24/255)
    static let slate = Color(red: 22/255, green: 27/255, blue: 38/255)
    static let aurora = Color(red: 64/255, green: 206/255, blue: 199/255)
    static let ember = Color(red: 252/255, green: 198/255, blue: 112/255)
    static let quartz = Color(red: 165/255, green: 176/255, blue: 198/255)
    static let wine = Color(red: 65/255, green: 18/255, blue: 39/255)
    static let success = Color(red: 118/255, green: 207/255, blue: 165/255)
    static let warning = Color(red: 255/255, green: 120/255, blue: 94/255)

    static let background = night
    static let surface = slate
    static let card = abyss
    static let overlay = slate.opacity(0.7)
    static let highlight = ember
    static let accent = quartz
    static let blueAccent = aurora
    static let charcoal = night
    static let graphite = slate
    static let obsidian = abyss
    static let platinum = ember

    static func gradientPrimary() -> LinearGradient {
        LinearGradient(colors: [Color(red: 0.12, green: 0.18, blue: 0.4), Color(red: 0.05, green: 0.06, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func gradientHighlight() -> LinearGradient {
        LinearGradient(colors: [ember, aurora.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
    }
}

enum ZhymTypography {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func numeric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct ZhymCardBackground: ViewModifier {
    var padding: CGFloat = 22
    var blur: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(ZhymPalette.abyss.opacity(0.7))
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(ZhymPalette.quartz.opacity(0.2), lineWidth: 1)
                    )
            )
    }
}

struct ZhymGlowBorder: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(ZhymPalette.gradientHighlight().opacity(0.4), lineWidth: 1.2)
                    .blur(radius: 4)
            )
    }
}

extension View {
    func zhymCard(padding: CGFloat = 22) -> some View {
        modifier(ZhymCardBackground(padding: padding))
    }

    func zhymCapsule(background: Color = ZhymPalette.slate, foreground: Color = ZhymPalette.quartz) -> some View {
        self
            .font(ZhymTypography.label(13, weight: .medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Capsule().fill(background))
            .foregroundStyle(foreground)
    }

    func zhymGlowBorder() -> some View {
        modifier(ZhymGlowBorder())
    }
}

struct ZhymButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZhymTypography.label(18, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(variant == .primary ? Color.black : ZhymPalette.ember)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(buttonBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(variant == .primary ? Color.clear : ZhymPalette.ember.opacity(0.6), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var buttonBackground: AnyShapeStyle {
        if variant == .primary {
            return AnyShapeStyle(ZhymPalette.gradientHighlight())
        } else {
            return AnyShapeStyle(Color.clear)
        }
    }
}

extension ButtonStyle where Self == ZhymButtonStyle {
    static var primaryZhym: ZhymButtonStyle { ZhymButtonStyle(variant: .primary) }
    static var secondaryZhym: ZhymButtonStyle { ZhymButtonStyle(variant: .secondary) }
}
