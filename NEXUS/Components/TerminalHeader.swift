import SwiftUI

struct TerminalHeader: View {
    let titleKey: String
    var subtitleKey: String?
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if let onBack {
                Button(action: onBack) { Image(systemName: "chevron.left") }
                    .buttonStyle(TerminalButtonStyle())
                    .help(Text("action.back"))
                    .accessibilityLabel(Text("action.back"))
            }
            VStack(alignment: .leading, spacing: 3) {
                TerminalRevealText(localizedKey: titleKey, intervalMilliseconds: 18)
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                if let subtitleKey { Text(LocalizedStringKey(subtitleKey)).foregroundStyle(TerminalTokens.phosphorMuted) }
            }
            Spacer()
            Text(Date.now, style: .time).foregroundStyle(TerminalTokens.phosphorMuted).monospacedDigit()
        }
        .padding(16)
        .background(TerminalTokens.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(TerminalTokens.border).frame(height: 1) }
    }
}
