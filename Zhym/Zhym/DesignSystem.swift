import SwiftUI

enum ZhymPalette {
    static let background = Color(red: 12/255, green: 17/255, blue: 29/255)
    static let surface = Color(red: 21/255, green: 28/255, blue: 46/255)
    static let card = Color(red: 27/255, green: 36/255, blue: 57/255)
    static let overlay = Color(red: 35/255, green: 45/255, blue: 71/255)
    static let highlight = Color(red: 247/255, green: 211/255, blue: 33/255)
    static let blueAccent = Color(red: 72/255, green: 132/255, blue: 255/255)
    static let muted = Color(red: 129/255, green: 145/255, blue: 184/255)
    static let success = Color(red: 110/255, green: 206/255, blue: 127/255)
    static let warning = Color(red: 242/255, green: 120/255, blue: 75/255)

    // Legacy aliases while screens transition
    static let charcoal = background
    static let graphite = surface
    static let obsidian = card
    static let platinum = highlight
    static let accent = muted
}

enum ZhymTypography {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static func numeric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct ZhymCardBackground: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ZhymPalette.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ZhymPalette.overlay.opacity(0.35), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func zhymCard(padding: CGFloat = 20) -> some View {
        modifier(ZhymCardBackground(padding: padding))
    }

    func zhymCapsule(background: Color = ZhymPalette.overlay, foreground: Color = ZhymPalette.muted) -> some View {
        self
            .font(ZhymTypography.label(13, weight: .medium))
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .background(Capsule().fill(background))
            .foregroundStyle(foreground)
    }
}

struct ZhymButtonStyle: ButtonStyle {
    enum Variant { case primary, secondary }
    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZhymTypography.label(17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .foregroundStyle(variant == .primary ? Color.black : ZhymPalette.highlight)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(variant == .primary ? ZhymPalette.highlight : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(variant == .primary ? Color.clear : ZhymPalette.highlight.opacity(0.6), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ZhymButtonStyle {
    static var primaryZhym: ZhymButtonStyle { ZhymButtonStyle(variant: .primary) }
    static var secondaryZhym: ZhymButtonStyle { ZhymButtonStyle(variant: .secondary) }
}
