import SwiftUI
import SwiftData

struct MorningBriefingView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var courses: [Course]
    @Query private var rules: [StudyScheduleRule]
    @Query private var attendance: [AttendanceRecord]
    @Query private var studyTasks: [StudyTask]
    @Query private var studySessions: [StudySession]
    @Query private var plannedWorkouts: [PlannedWorkoutSession]
    @Query private var workoutPlans: [WorkoutPlan]
    @Query private var completedWorkouts: [WorkoutRecord]
    @Query private var calendarEntries: [CalendarEntry]
    @Query private var assessments: [OBSAssessment]
    @Query private var universityCourses: [UniversityCourse]
    @Query private var organizationProjects: [ProjectRecord]
    @Query private var organizationTasks: [OrganizationTask]
    @Query private var placements: [PlannedTaskPlacement]
    @Query private var focusSessions: [FocusSessionRecord]

    let date: Date
    let acknowledge: () -> Void

    private var snapshot: DailyPlanSnapshot {
        DailyPlanAggregator.snapshot(date: date, courses: courses, rules: rules, attendance: attendance,
            studyTasks: studyTasks, studySessions: studySessions, plannedWorkouts: plannedWorkouts,
            workoutPlans: workoutPlans, completedWorkouts: completedWorkouts, calendarEntries: calendarEntries,
            assessments: assessments, universityCourses: universityCourses, debts: [], recurringTransactions: [], notes: [],
            organizationProjects: organizationProjects, organizationTasks: organizationTasks,
            taskPlacements: placements, focusSessions: focusSessions)
    }

    private var summary: MorningBriefingSummary {
        MorningBriefingService.make(date: date, snapshot: snapshot, attendance: attendance,
            studyTasks: studyTasks, organizationTasks: organizationTasks, calendarEntries: calendarEntries,
            assessments: assessments, focusSessions: focusSessions)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("briefing.title").font(.system(.title2, design: .monospaced, weight: .bold)).phosphorGlow()
                    Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .foregroundStyle(TerminalTokens.phosphorMuted)
                }
                Spacer()
                Text("briefing.localOnly").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
            }.padding(18).background(TerminalTokens.surface)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("briefing.greeting").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 10) {
                        metric("briefing.lessons", value: "\(summary.heldLessonCount)", symbol: "book.closed")
                        metric("briefing.flexibleTasks", value: "\(summary.flexibleTaskCount)", symbol: "checklist")
                        metric("briefing.freeTime", value: duration(summary.freeTimeSeconds), symbol: "clock")
                        metric("briefing.deadlines", value: "\(summary.imminentDeadlines.count)", symbol: "exclamationmark.triangle")
                    }

                    if summary.cancelledLessonCount > 0 {
                        Label(String(format: String(localized: "briefing.cancelledLessons"), summary.cancelledLessonCount), systemImage: "nosign")
                            .foregroundStyle(TerminalTokens.warning).terminalBriefingPanel()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("briefing.imminentTitle").font(.headline)
                        if summary.imminentDeadlines.isEmpty {
                            Text("briefing.noDeadlines").foregroundStyle(TerminalTokens.phosphorMuted)
                        } else {
                            ForEach(summary.imminentDeadlines.prefix(6)) { deadline in
                                HStack { Image(systemName: "chevron.right"); Text(deadline.title).lineLimit(1); Spacer(); Text(deadline.date, style: .date).monospacedDigit() }
                            }
                        }
                    }.terminalBriefingPanel()

                    if summary.isEmpty {
                        Text("briefing.emptyHonest").foregroundStyle(TerminalTokens.phosphorMuted).terminalBriefingPanel()
                    }
                    if summary.focusSecondsToday > 0 {
                        Label(String(format: String(localized: "briefing.focusToday"), duration(summary.focusSecondsToday)), systemImage: "timer")
                            .terminalBriefingPanel()
                    }
                    Text("briefing.freeTimeHelp").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                }.padding(18)
            }

            HStack {
                Button("briefing.skip") { finish() }.buttonStyle(TerminalButtonStyle()).keyboardShortcut(.escape, modifiers: [])
                Spacer()
                Button("briefing.startDay") { finish() }.buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.return, modifiers: [])
            }.padding(16).background(TerminalTokens.surface.opacity(0.55))
        }
        .frame(minWidth: 660, minHeight: 560)
        .background(TerminalTokens.background)
        .accessibilityIdentifier("briefing.screen")
        .interactiveDismissDisabled()
    }

    private func metric(_ key: String, value: String, symbol: String) -> some View {
        HStack { Image(systemName: symbol).font(.title2); VStack(alignment: .leading) { Text(value).font(.system(.title2, design: .monospaced, weight: .bold)).monospacedDigit(); Text(LocalizedStringKey(key)).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer() }.terminalBriefingPanel()
    }

    private func duration(_ seconds: Int) -> String {
        let hours = seconds / 3_600; let minutes = (seconds % 3_600) / 60
        if hours > 0 { return String(format: String(localized: "briefing.durationHoursMinutes"), hours, minutes) }
        return String(format: String(localized: "briefing.durationMinutes"), minutes)
    }

    private func finish() { acknowledge(); dismiss() }
}

private extension View {
    func terminalBriefingPanel() -> some View {
        padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(TerminalTokens.surface.opacity(0.7))
            .overlay(Rectangle().stroke(TerminalTokens.border))
    }
}
