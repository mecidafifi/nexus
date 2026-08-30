import SwiftUI

enum TerminalTokens {
    static let background = Color(red: 0.018, green: 0.055, blue: 0.032)
    static let surface = Color(red: 0.025, green: 0.082, blue: 0.045)
    static let surfaceRaised = Color(red: 0.035, green: 0.115, blue: 0.060)
    static let phosphor = Color(red: 0.47, green: 1.0, blue: 0.60)
    static let phosphorMuted = Color(red: 0.30, green: 0.68, blue: 0.40)
    static let border = Color(red: 0.22, green: 0.52, blue: 0.31)
    static let success = Color(red: 0.47, green: 1.0, blue: 0.60)
    static let warning = Color(red: 0.96, green: 0.78, blue: 0.30)
    static let error = Color(red: 1.0, green: 0.42, blue: 0.38)
    static let disabled = Color(red: 0.31, green: 0.38, blue: 0.33)
    static let cornerRadius: CGFloat = 3
    static let spacing: CGFloat = 12

    static func font(_ style: Font.TextStyle = .body, scale: Double = 1) -> Font {
        .system(style, design: .monospaced).width(.standard)
    }
}

private struct TerminalTextStyle: ViewModifier {
    @AppStorage("appearance.textScale") private var textScale = 1.0
    func body(content: Content) -> some View {
        content
            .font(TerminalTokens.font())
            .foregroundStyle(TerminalTokens.phosphor)
            .scaleEffect(textScale, anchor: .leading)
    }
}

extension View {
    func terminalText() -> some View { modifier(TerminalTextStyle()) }
}
