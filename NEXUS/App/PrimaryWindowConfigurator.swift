import AppKit
import SwiftUI

@MainActor
struct PrimaryWindowConfigurator: NSViewRepresentable {
    let transitionComplete: Bool

    final class Coordinator {
        private var didResolveWindow = false
        private var appliedProvisionalFrame = false
        private var finalFrameScheduled = false

        func configure(_ window: NSWindow, transitionComplete: Bool) {
            guard !didResolveWindow else { return }

            let defaults = UserDefaults.standard
            let hasAppliedDefault = defaults.bool(forKey: PrimaryWindowLaunchPolicy.didApplyDefaultMaximizeKey)
            guard PrimaryWindowLaunchPolicy.shouldApplyDefaultMaximize(hasAppliedDefault: hasAppliedDefault) else {
                didResolveWindow = true
                return
            }
            guard !window.styleMask.contains(.fullScreen), let screen = window.screen ?? NSScreen.main else { return }

            if !appliedProvisionalFrame {
                window.setFrame(screen.visibleFrame, display: true, animate: false)
                appliedProvisionalFrame = true
            }
            if transitionComplete {
                guard !finalFrameScheduled else { return }
                finalFrameScheduled = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak window] in
                    guard let self, let window, let finalScreen = window.screen ?? NSScreen.main else { return }
                    window.setFrame(finalScreen.visibleFrame, display: true, animate: false)
                    defaults.set(true, forKey: PrimaryWindowLaunchPolicy.didApplyDefaultMaximizeKey)
                    self.didResolveWindow = true
                }
            }
        }
    }

    final class WindowProbeView: NSView {
        var onWindowAvailable: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { onWindowAvailable?(window) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WindowProbeView {
        let view = WindowProbeView(frame: .zero)
        view.onWindowAvailable = { [weak coordinator = context.coordinator] window in
            coordinator?.configure(window, transitionComplete: transitionComplete)
        }
        return view
    }

    func updateNSView(_ nsView: WindowProbeView, context: Context) {
        if let window = nsView.window {
            context.coordinator.configure(window, transitionComplete: transitionComplete)
        }
    }
}
