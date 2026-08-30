import SwiftUI

struct BootSplashView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TerminalWindow {
            ZStack {
                BootNetworkCore(reduceMotion: reduceMotion)
                    .frame(maxWidth: 720, maxHeight: 540)
                    .accessibilityHidden(true)

                VStack(spacing: 18) {
                    TerminalRevealText(localizedKey: "boot.systemTitle", intervalMilliseconds: 34)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .tracking(4)

                    Spacer()

                    VStack(spacing: 8) {
                        TerminalRevealText(localizedKey: "boot.initializing", intervalMilliseconds: 28)
                            .font(.system(.headline, design: .monospaced))
                        Text(LocalizedStringKey(reduceMotion ? "boot.motionReduced" : "boot.networkOnline"))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(TerminalTokens.phosphorMuted)
                    }

                    Button {
                        appState.completeBoot()
                    } label: {
                        Text("boot.continue")
                    }
                    .buttonStyle(TerminalButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .accessibilityHint(Text("boot.continueHint"))
                }
                .padding(.vertical, 46)
            }
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("boot.accessibilityLabel"))
            .accessibilityIdentifier("boot.screen")
        }
    }
}

struct BootNetworkCore: View {
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let phase = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate * 0.34
                let center = CGPoint(x: size.width / 2, y: size.height / 2 - 12)
                let radius = min(size.width, size.height) * 0.225
                let strong = TerminalTokens.phosphor.opacity(0.78)
                let faint = TerminalTokens.border.opacity(0.52)

                let outer = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(outer, with: .color(strong), lineWidth: 1.1)

                for latitude in -3...3 where latitude != 0 {
                    let normalized = CGFloat(latitude) / 4
                    let y = center.y + normalized * radius
                    let halfWidth = radius * sqrt(max(0, 1 - normalized * normalized))
                    let latitudePath = Path(ellipseIn: CGRect(x: center.x - halfWidth, y: y - 7, width: halfWidth * 2, height: 14))
                    context.stroke(latitudePath, with: .color(faint), lineWidth: 0.75)
                }

                for index in 0..<8 {
                    let angle = phase + Double(index) * .pi / 8
                    let width = max(3, radius * 2 * abs(cos(angle)))
                    let meridian = Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - radius, width: width, height: radius * 2))
                    context.stroke(meridian, with: .color(index.isMultiple(of: 2) ? strong : faint), lineWidth: 0.7)
                }

                let nodeAngles: [Double] = [-2.75, -2.1, -1.35, -0.42, 0.35, 1.08, 1.78, 2.48]
                for (index, baseAngle) in nodeAngles.enumerated() {
                    let angle = baseAngle + (reduceMotion ? 0 : sin(phase * 0.38 + Double(index)) * 0.018)
                    let distance = radius * (index.isMultiple(of: 2) ? 1.72 : 1.48)
                    let node = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance * 0.72)
                    let edge = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    var link = Path()
                    link.move(to: edge)
                    link.addLine(to: node)
                    context.stroke(link, with: .color(faint), lineWidth: 0.7)
                    context.fill(Path(ellipseIn: CGRect(x: node.x - 2.5, y: node.y - 2.5, width: 5, height: 5)), with: .color(strong))
                    context.stroke(Path(ellipseIn: CGRect(x: node.x - 8, y: node.y - 8, width: 16, height: 16)), with: .color(faint), lineWidth: 0.55)
                }
            }
        }
        .phosphorGlow()
    }
}
