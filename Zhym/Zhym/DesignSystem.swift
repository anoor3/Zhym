import SwiftUI

enum ZhymPalette {
    static let charcoal = Color(red: 9/255.0, green: 11/255.0, blue: 15/255.0)
    static let graphite = Color(red: 19/255.0, green: 22/255.0, blue: 28/255.0)
    static let obsidian = Color(red: 32/255.0, green: 36/255.0, blue: 44/255.0)
    static let platinum = Color(red: 198/255.0, green: 205/255.0, blue: 210/255.0)
    static let accent = Color(red: 134/255.0, green: 146/255.0, blue: 160/255.0)
    static let warning = Color(red: 186/255.0, green: 79/255.0, blue: 62/255.0)
    static let success = Color(red: 98/255.0, green: 165/255.0, blue: 120/255.0)
}

enum ZhymTypography {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .thin, design: .rounded)
    }

    static func numeric(_ size: CGFloat) -> Font {
        .system(size: size, weight: .light, design: .monospaced)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
}

struct ZhymBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(colors: [ZhymPalette.graphite, ZhymPalette.obsidian], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ZhymPalette.charcoal.opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func zhymCard() -> some View {
        modifier(ZhymBackground())
    }
}

struct ZhymButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ZhymTypography.label(18))
            .foregroundStyle(isPrimary ? Color.black : ZhymPalette.platinum)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isPrimary ? ZhymPalette.platinum : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ZhymPalette.platinum.opacity(0.3), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ZhymButtonStyle {
    static var primaryZhym: ZhymButtonStyle { ZhymButtonStyle(isPrimary: true) }
    static var secondaryZhym: ZhymButtonStyle { ZhymButtonStyle(isPrimary: false) }
}
