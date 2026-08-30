import SwiftUI

enum PadTokens {
    static let background = Color(red: 0.008, green: 0.055, blue: 0.035)
    static let panel = Color(red: 0.018, green: 0.095, blue: 0.060)
    static let panelRaised = Color(red: 0.025, green: 0.13, blue: 0.08)
    static let phosphor = Color(red: 0.43, green: 0.96, blue: 0.57)
    static let phosphorDim = Color(red: 0.26, green: 0.63, blue: 0.38)
    static let warning = Color(red: 0.96, green: 0.76, blue: 0.25)
    static let error = Color(red: 1.0, green: 0.38, blue: 0.35)
    static let cornerRadius: CGFloat = 12
    static let minimumTap: CGFloat = 48
}

struct TerminalBackground: View {
    var showGlobe = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            PadTokens.background
            if showGlobe { GlobeBackdrop().opacity(reduceTransparency ? 0.035 : 0.075) }
            Canvas { context, size in
                let line = Path { path in
                    stride(from: 0.0, through: size.height, by: 5).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                context.stroke(line, with: .color(PadTokens.phosphor.opacity(0.025)), lineWidth: 0.5)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GlobeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height) * 0.72
            ZStack {
                Circle().stroke(PadTokens.phosphor, lineWidth: 1)
                ForEach([-0.55, -0.28, 0, 0.28, 0.55], id: \.self) { scale in
                    Ellipse().stroke(PadTokens.phosphor, lineWidth: 0.7)
                        .frame(width: size, height: size * sqrt(max(0.05, 1 - scale * scale)))
                }
                ForEach([0.28, 0.52, 0.78], id: \.self) { ratio in
                    Ellipse().stroke(PadTokens.phosphor, lineWidth: 0.7).frame(width: size * ratio, height: size)
                }
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width * 0.72, y: proxy.size.height * 0.58)
        }
    }
}

struct TerminalCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(PadTokens.phosphorDim)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PadTokens.panel.opacity(0.94))
        .overlay(RoundedRectangle(cornerRadius: PadTokens.cornerRadius).stroke(PadTokens.phosphorDim.opacity(0.65)))
        .clipShape(RoundedRectangle(cornerRadius: PadTokens.cornerRadius))
    }
}

struct TerminalProgressBar: View {
    let completed: Int
    let total: Int
    var progress: Double { total == 0 ? 0 : min(1, Double(completed) / Double(total)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PadTokens.phosphor.opacity(0.12))
                    Capsule().fill(PadTokens.phosphor).frame(width: geo.size.width * progress)
                }
            }.frame(height: 8)
            Text("\(completed)/\(total) • \(Int(progress * 100))%")
                .font(.system(.caption, design: .monospaced))
                .accessibilityLabel("\(total) görevin \(completed) tanesi tamamlandı")
        }
    }
}

extension View {
    func terminalPage() -> some View {
        self.fontDesign(.monospaced).foregroundStyle(PadTokens.phosphor)
    }
}
