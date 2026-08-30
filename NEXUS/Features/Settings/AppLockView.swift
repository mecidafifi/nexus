import SwiftUI

struct AppLockView: View {
    @ObservedObject var coordinator: AppLockCoordinator

    var body: some View {
        TerminalWindow {
            VStack(spacing: 18) {
                Image(systemName: "touchid").font(.system(size: 54)).accessibilityHidden(true)
                Text("lock.screen.title").font(.title2.bold())
                Text("lock.screen.message").foregroundStyle(TerminalTokens.phosphorMuted).multilineTextAlignment(.center)
                switch coordinator.state {
                case .initializing, .authenticating:
                    ProgressView().accessibilityLabel(Text("lock.authenticating"))
                case .locked:
                    Button("lock.unlock") { Task { await coordinator.unlock() } }
                        .buttonStyle(TerminalPrimaryButtonStyle())
                        .keyboardShortcut(.return, modifiers: [])
                case .unavailable(let detail):
                    Label("lock.unavailable.title", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(TerminalTokens.warning)
                    Text(detail).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).multilineTextAlignment(.center)
                    Button("lock.disableUnavailable") { coordinator.disable() }.buttonStyle(TerminalButtonStyle())
                case .disabled, .unlocked:
                    EmptyView()
                }
                if let error = coordinator.errorMessage {
                    Text(error).foregroundStyle(TerminalTokens.error).font(.caption).multilineTextAlignment(.center)
                }
                Text("lock.noPasswordFallback").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).multilineTextAlignment(.center)
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lock.screen")
        }
    }
}

struct PrivacyMaskView: View {
    var body: some View {
        TerminalWindow {
            VStack(spacing: 12) {
                Image(systemName: "eye.slash").font(.largeTitle)
                Text("lock.privacyMask.title").font(.headline)
                Text("lock.privacyMask.message").foregroundStyle(TerminalTokens.phosphorMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("privacy.mask")
        }
    }
}
