import SwiftUI

struct TerminalEmptyState: View {
    let titleKey: String
    let messageKey: String
    var actionKey: String?
    var action: (() -> Void)?
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.dashed").font(.largeTitle)
            Text(LocalizedStringKey(titleKey)).font(.headline)
            Text(LocalizedStringKey(messageKey)).foregroundStyle(TerminalTokens.phosphorMuted).multilineTextAlignment(.center)
            if let actionKey, let action { Button(LocalizedStringKey(actionKey), action: action).buttonStyle(TerminalButtonStyle()) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(32)
    }
}

struct TerminalErrorState: View {
    let message: String
    var retry: (() -> Void)?
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "xmark.octagon").font(.largeTitle)
            Text("state.error").font(.headline)
            Text(message).multilineTextAlignment(.center)
            if let retry { Button("action.retry", action: retry).buttonStyle(TerminalButtonStyle()) }
        }.foregroundStyle(TerminalTokens.error).padding(32)
    }
}

struct TerminalLoadingState: View {
    var body: some View { HStack { ProgressView(); Text("state.loading") }.padding().accessibilityElement(children: .combine) }
}
