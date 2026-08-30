import SwiftUI

struct TerminalEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(PadTokens.phosphor)
        } description: { Text(message).foregroundStyle(PadTokens.phosphorDim) }
    }
}

struct TerminalErrorState: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(PadTokens.error)
            .padding().accessibilityLabel("Hata: \(message)")
    }
}

struct TerminalStatusBadge: View {
    let text: String
    var color: Color = PadTokens.phosphorDim
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 5)
            .overlay(Capsule().stroke(color))
            .foregroundStyle(color)
    }
}
