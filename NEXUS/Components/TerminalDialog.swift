import SwiftUI

struct TerminalDialog<Content: View>: View {
    let titleKey: String
    let content: Content
    init(titleKey: String, @ViewBuilder content: () -> Content) { self.titleKey = titleKey; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey(titleKey)).font(.system(.title2, design: .monospaced, weight: .bold))
            content
        }
        .padding(20).frame(minWidth: 440)
        .background(TerminalTokens.background)
        .overlay(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius).stroke(TerminalTokens.border))
    }
}
