import SwiftUI
import SwiftData

struct FocusModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var studyTasks: [StudyTask]
    @Query private var organizationTasks: [OrganizationTask]
    @Query private var calendarEntries: [CalendarEntry]
    @ObservedObject var controller: FocusSessionController
    @State private var pendingOutcome: FocusOutcome?
    @State private var showShortConfirmation = false
    @State private var showZeroConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let elapsed = controller.elapsedSeconds()
            VStack(spacing: 22) {
                HStack {
                    Text("focus.systemTitle").font(.system(.title2, design: .monospaced, weight: .bold)).phosphorGlow()
                    Spacer()
                    Text(controller.state?.isPaused == true ? "focus.state.paused" : "focus.state.running")
                        .font(.caption).foregroundStyle(controller.state?.isPaused == true ? TerminalTokens.warning : TerminalTokens.success)
                }
                Divider().overlay(TerminalTokens.border)
                VStack(spacing: 8) {
                    Text(controller.state?.request.title ?? String(localized: "focus.unknownTask"))
                        .font(.title3).fontWeight(.semibold).multilineTextAlignment(.center)
                    Text(clock(elapsed)).font(.system(size: 58, weight: .medium, design: .monospaced)).monospacedDigit().phosphorGlow()
                    if let planned = controller.state?.request.plannedDurationSeconds {
                        Text(String(format: String(localized: "focus.remaining"), clock(max(planned - elapsed, 0))))
                            .foregroundStyle(TerminalTokens.phosphorMuted).monospacedDigit()
                        TerminalProgressBar(value: min(Double(elapsed) / Double(max(planned, 1)), 1), labelKey: "focus.progress")
                    } else {
                        Text("focus.noPlannedDuration").foregroundStyle(TerminalTokens.phosphorMuted)
                    }
                }.frame(maxWidth: .infinity).padding(20).background(TerminalTokens.surface.opacity(0.65)).overlay(Rectangle().stroke(TerminalTokens.border))

                if let errorMessage { Label(errorMessage, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error) }
                Text("focus.runtimeLimitation").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if controller.state?.isPaused == true {
                        Button("focus.resume") { controller.resume() }.buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.space, modifiers: [])
                    } else {
                        Button("focus.pause") { controller.pause() }.buttonStyle(TerminalButtonStyle()).keyboardShortcut(.space, modifiers: [])
                    }
                    Spacer()
                    Button("focus.stop") { requestFinish(.stopped) }.buttonStyle(TerminalButtonStyle())
                    Button("focus.complete") { requestFinish(.completed) }.buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.return, modifiers: [])
                }
            }.padding(22)
        }
        .frame(minWidth: 560, minHeight: 430)
        .background(TerminalTokens.background)
        .accessibilityIdentifier("focus.screen")
        .interactiveDismissDisabled()
        .confirmationDialog("focus.short.title", isPresented: $showShortConfirmation) {
            Button("focus.short.save") { if let pendingOutcome { persist(pendingOutcome) } }
            Button("focus.discard", role: .destructive) { discard() }
            Button("focus.continue", role: .cancel) { pendingOutcome = nil }
        } message: { Text("focus.short.message") }
        .confirmationDialog("focus.zero.title", isPresented: $showZeroConfirmation) {
            Button("focus.discard", role: .destructive) { discard() }
            Button("focus.continue", role: .cancel) { pendingOutcome = nil }
        } message: { Text("focus.zero.message") }
    }

    private func requestFinish(_ outcome: FocusOutcome) {
        errorMessage = nil; pendingOutcome = outcome
        switch controller.readiness() {
        case .noElapsedTime: showZeroConfirmation = true
        case .shortSession: showShortConfirmation = true
        case .ready: persist(outcome)
        }
    }

    private func persist(_ outcome: FocusOutcome) {
        guard let snapshot = controller.snapshot(outcome: outcome) else { errorMessage = String(localized: "focus.error.duration"); return }
        do {
            try FocusPersistenceService.save(snapshot, studyTasks: studyTasks, organizationTasks: organizationTasks,
                                             calendarEntries: calendarEntries, context: context)
            controller.clear(); dismiss()
        } catch { errorMessage = error.localizedDescription }
    }

    private func discard() { controller.clear(); dismiss() }
    private func clock(_ seconds: Int) -> String { String(format: "%02d:%02d:%02d", seconds / 3_600, (seconds % 3_600) / 60, seconds % 60) }
}
