import SwiftUI

struct TerminalWindow<Content: View>: View {
    @AppStorage("appearance.highContrast") private var highContrast = false
    @AppStorage("appearance.textScale") private var textScale = 1.0
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            TerminalTokens.background.ignoresSafeArea()
            content
                .fontDesign(.monospaced)
                .foregroundStyle(TerminalTokens.phosphor)
                .contrast(highContrast ? 1.25 : 1)
            ScanlineOverlay().ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .tint(TerminalTokens.phosphor)
        .environment(\.dynamicTypeSize, preferredTypeSize)
    }

    private var preferredTypeSize: DynamicTypeSize {
        if textScale >= 1.2 { return .accessibility1 }
        if textScale >= 1.05 { return .xLarge }
        if textScale < 0.95 { return .small }
        return .large
    }
}
