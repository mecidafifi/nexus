import SwiftUI

struct ScanlineOverlay: View {
    @AppStorage("appearance.scanlines") private var enabled = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if enabled && !reduceTransparency {
            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    let path = Path(CGRect(x: 0, y: y, width: size.width, height: 1))
                    context.fill(path, with: .color(.black.opacity(0.09)))
                    y += 4
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

struct PhosphorGlow: ViewModifier {
    @AppStorage("appearance.glow") private var glow = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        content.shadow(color: glow && !reduceTransparency ? TerminalTokens.phosphor.opacity(0.16) : .clear, radius: 3)
    }
}

extension View {
    func phosphorGlow() -> some View { modifier(PhosphorGlow()) }
}
