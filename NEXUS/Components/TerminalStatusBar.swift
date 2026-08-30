import SwiftUI

enum TerminalStatusKind { case neutral, loading, success, warning, error }

struct TerminalStatusBar: View {
    let messageKey: String
    var kind: TerminalStatusKind = .neutral
    var body: some View {
        HStack {
            Image(systemName: symbol)
            TerminalRevealText(localizedKey: messageKey, intervalMilliseconds: 12, showsCursor: false)
            Spacer()
            Text("shortcut.help")
        }
        .font(.system(.caption, design: .monospaced))
        .foregroundStyle(color)
        .padding(.horizontal, 12).frame(height: 28)
        .background(TerminalTokens.surface)
        .accessibilityElement(children: .combine)
    }
    private var symbol: String { switch kind { case .neutral: "terminal"; case .loading: "hourglass"; case .success: "checkmark.circle"; case .warning: "exclamationmark.triangle"; case .error: "xmark.octagon" } }
    private var color: Color { switch kind { case .neutral, .loading: TerminalTokens.phosphorMuted; case .success: TerminalTokens.success; case .warning: TerminalTokens.warning; case .error: TerminalTokens.error } }
}
