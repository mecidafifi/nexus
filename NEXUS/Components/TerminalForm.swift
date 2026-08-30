import SwiftUI

struct TerminalForm<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(TerminalTokens.background)
            .fontDesign(.monospaced)
    }
}
