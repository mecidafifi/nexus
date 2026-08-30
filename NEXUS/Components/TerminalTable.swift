import SwiftUI

struct TerminalTable<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(spacing: 0) { content }
            .background(TerminalTokens.surface.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius).stroke(TerminalTokens.border))
            .clipShape(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius))
    }
}

struct TerminalTableRow<Content: View>: View {
    var selected = false
    let content: Content
    init(selected: Bool = false, @ViewBuilder content: () -> Content) { self.selected = selected; self.content = content() }
    var body: some View {
        content.padding(.horizontal, 12).frame(minHeight: 40)
            .background(selected ? TerminalTokens.phosphor.opacity(0.12) : .clear)
            .overlay(alignment: .bottom) { Rectangle().fill(TerminalTokens.border.opacity(0.45)).frame(height: 1) }
    }
}
