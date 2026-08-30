import SwiftUI

struct StudyOverviewView: View {
    let courses: [Course]
    let tasks: [StudyTask]
    let goals: [StudyGoal]
    let sessions: [StudySession]
    let focusSessions: [FocusSessionRecord]
    @ObservedObject var viewModel: StudyViewModel
    let startFocus: () -> Void

    private var startOfWeek: Date { Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                    metric("overview.courses", value: "\(courses.count)", symbol: "books.vertical")
                    metric("overview.openTasks", value: "\(tasks.filter { $0.status != .completed }.count)", symbol: "checklist")
                    metric("overview.weekMinutes", value: "\(viewModel.totalMinutes(sessions, since: startOfWeek) + viewModel.totalFocusMinutes(focusSessions, since: startOfWeek))", symbol: "timer")
                }
                Button(action: startFocus) { Label("focus.freeStudyStart", systemImage: "timer") }
                    .buttonStyle(TerminalPrimaryButtonStyle()).accessibilityHint(Text("focus.startHint"))
                VStack(alignment: .leading, spacing: 8) {
                    Text("overview.taskProgress").font(.headline)
                    TerminalProgressBar(value: viewModel.completedTaskRatio(tasks), labelKey: "overview.completed")
                }.terminalPanel()
                Text("overview.activeGoals").font(.headline)
                if goals.isEmpty { Text("overview.noGoals").foregroundStyle(TerminalTokens.phosphorMuted).terminalPanel() }
                else { ForEach(goals.prefix(4)) { goal in VStack(alignment: .leading, spacing: 8) { Text(goal.title); TerminalProgressBar(value: viewModel.goalProgress(goal, sessions: sessions, focusSessions: focusSessions)) }.terminalPanel() } }
            }.padding(18)
        }
    }

    private func metric(_ key: String, value: String, symbol: String) -> some View {
        HStack { Image(systemName: symbol).font(.title2); VStack(alignment: .leading) { Text(value).font(.system(.title, design: .monospaced, weight: .bold)).monospacedDigit(); Text(LocalizedStringKey(key)).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer() }.terminalPanel()
    }
}

private extension View {
    func terminalPanel() -> some View { padding(14).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.surface).overlay(RoundedRectangle(cornerRadius: TerminalTokens.cornerRadius).stroke(TerminalTokens.border)) }
}
