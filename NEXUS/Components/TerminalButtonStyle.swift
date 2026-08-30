import SwiftUI

struct TerminalButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced, weight: .medium))
            .foregroundStyle(isEnabled ? TerminalTokens.phosphor : TerminalTokens.disabled)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(configuration.isPressed ? TerminalTokens.phosphor.opacity(0.18) : TerminalTokens.surfaceRaised)
            .overlay(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius).stroke(isEnabled ? TerminalTokens.border : TerminalTokens.disabled, lineWidth: differentiate ? 2 : 1))
            .clipShape(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct TerminalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced, weight: .bold))
            .foregroundStyle(TerminalTokens.background)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(TerminalTokens.phosphor.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius))
    }
}
