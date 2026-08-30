import SwiftUI
import SwiftData

enum OverdueDecision: String, CaseIterable {
    case tomorrow, anotherDate, keepOverdue, cancel
}

struct OverdueReviewItem: Identifiable, Equatable {
    enum Source: Equatable { case study, organization }
    let id: UUID
    let source: Source
    let title: String
    let dueDate: Date
}

enum OverdueReviewService {
    static func items(studyTasks: [StudyTask], organizationTasks: [OrganizationTask], reviewDate: Date = .now, calendar: Calendar = .current) -> [OverdueReviewItem] {
        let day = calendar.startOfDay(for: reviewDate)
        let study = studyTasks.compactMap { task -> OverdueReviewItem? in
            guard let due = task.dueDate, due < day, task.status != .completed, task.status != .cancelled,
                  task.overdueReviewedAt.map({ !calendar.isDate($0, inSameDayAs: reviewDate) }) ?? true else { return nil }
            return OverdueReviewItem(id: task.id, source: .study, title: task.title, dueDate: due)
        }
        let organization = organizationTasks.compactMap { task -> OverdueReviewItem? in
            guard let due = task.dueDate, due < day, task.status != .completed, task.status != .cancelled,
                  task.overdueReviewedAt.map({ !calendar.isDate($0, inSameDayAs: reviewDate) }) ?? true else { return nil }
            return OverdueReviewItem(id: task.id, source: .organization, title: task.title, dueDate: due)
        }
        return (study + organization).sorted { $0.dueDate == $1.dueDate ? $0.title < $1.title : $0.dueDate < $1.dueDate }
    }

    @MainActor
    static func apply(_ decision: OverdueDecision, to item: OverdueReviewItem, anotherDate: Date?, studyTasks: [StudyTask], organizationTasks: [OrganizationTask], reviewDate: Date = .now, calendar: Calendar = .current, context: ModelContext) throws {
        let targetDate: Date? = switch decision {
        case .tomorrow: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reviewDate))
        case .anotherDate: anotherDate.map { calendar.startOfDay(for: $0) }
        case .keepOverdue, .cancel: nil
        }
        if decision == .anotherDate && targetDate == nil { return }
        switch item.source {
        case .study:
            guard let task = studyTasks.first(where: { $0.id == item.id }) else { return }
            if decision == .cancel { task.status = .cancelled }
            else if let targetDate { task.dueDate = targetDate }
            task.overdueReviewedAt = reviewDate
            task.updatedAt = reviewDate
        case .organization:
            guard let task = organizationTasks.first(where: { $0.id == item.id }) else { return }
            if decision == .cancel { task.status = .cancelled }
            else if let targetDate { task.dueDate = targetDate }
            task.overdueReviewedAt = reviewDate
            task.updatedAt = reviewDate
        }
        try context.save()
    }
}

struct EveningReviewDeadline: Identifiable, Equatable {
    let id: String
    let title: String
    let date: Date
    let isOverdue: Bool
}

struct EveningReviewSummary: Equatable {
    let scheduledLessons: Int
    let heldLessons: Int
    let attendedLessons: Int
    let cancelledLessons: Int
    let completedTasks: Int
    let eligibleTasks: Int
    let focusSeconds: Int
    let gymPlanned: Int
    let gymPlannedCompleted: Int
    let gymLoggedCompleted: Int
    let deadlines: [EveningReviewDeadline]
    let overdueCount: Int
}

enum EveningReviewAcknowledgement {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func shouldSuggest(lastAcknowledgedDay: String, now: Date, endMinutes: Int, calendar: Calendar = .current) -> Bool {
        guard lastAcknowledgedDay != dayKey(for: now, calendar: calendar) else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) >= min(max(endMinutes, 0), 1_439)
    }
}

enum EveningReviewService {
    static func make(
        date: Date, occurrences: [LessonOccurrence], attendance: [AttendanceRecord],
        studyTasks: [StudyTask], organizationTasks: [OrganizationTask], calendarEntries: [CalendarEntry],
        placements: [PlannedTaskPlacement], focusSessions: [FocusSessionRecord],
        plannedWorkouts: [PlannedWorkoutSession], completedWorkouts: [WorkoutRecord],
        assessments: [OBSAssessment], calendar: Calendar = .current
    ) -> EveningReviewSummary {
        let day = calendar.startOfDay(for: date)
        let occurrenceIDs = Set(occurrences.map(\.id))
        let occurrenceRecords = attendance.filter { occurrenceIDs.contains($0.occurrenceID) }
        let heldStatuses: Set<AttendanceStatus> = [.present, .absent, .online, .late]
        let attendedStatuses: Set<AttendanceStatus> = [.present, .online, .late]
        let held = occurrenceRecords.filter { heldStatuses.contains($0.status) }.count
        let attended = occurrenceRecords.filter { attendedStatuses.contains($0.status) }.count
        let cancelled = occurrenceRecords.filter { $0.status == .cancelled }.count

        let placementKeys = Set(placements.filter { calendar.isDate($0.planDate, inSameDayAs: day) }.map { "\($0.sourceRaw):\($0.sourceRecordID.uuidString)" })
        let eligibleStudy = studyTasks.filter {
            $0.status != .cancelled && ($0.dueDate.map { calendar.isDate($0, inSameDayAs: day) } == true ||
                placementKeys.contains("\(TaskPlacementSource.studyTask.rawValue):\($0.id.uuidString)"))
        }
        let eligibleOrganization = organizationTasks.filter {
            $0.status != .cancelled && ($0.dueDate.map { calendar.isDate($0, inSameDayAs: day) } == true ||
                placementKeys.contains("\(TaskPlacementSource.organizationTask.rawValue):\($0.id.uuidString)"))
        }
        let eligibleCalendar = calendarEntries.filter {
            $0.kind == .task && (calendar.isDate($0.startDate, inSameDayAs: day) ||
                placementKeys.contains("\(TaskPlacementSource.calendarTask.rawValue):\($0.id.uuidString)"))
        }
        let completedTasks = eligibleStudy.filter { $0.status == .completed }.count +
            eligibleOrganization.filter { $0.status == .completed }.count +
            eligibleCalendar.filter(\.isCompleted).count
        let eligibleTasks = eligibleStudy.count + eligibleOrganization.count + eligibleCalendar.count

        let focusSeconds = focusSessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }.reduce(0) { $0 + max($1.elapsedSeconds, 0) }
        let planned = plannedWorkouts.filter { calendar.isDate($0.date, inSameDayAs: day) }
        let logged = completedWorkouts.filter { calendar.isDate($0.date, inSameDayAs: day) }

        var deadlines: [EveningReviewDeadline] = []
        for task in studyTasks where task.status != .completed && task.status != .cancelled {
            if let due = task.dueDate, due < calendar.date(byAdding: .day, value: 1, to: day)! {
                deadlines.append(.init(id: "study:\(task.id)", title: task.title, date: due, isOverdue: due < day))
            }
        }
        for task in organizationTasks where task.status != .completed && task.status != .cancelled {
            if let due = task.dueDate, due < calendar.date(byAdding: .day, value: 1, to: day)! {
                deadlines.append(.init(id: "organization:\(task.id)", title: task.title, date: due, isOverdue: due < day))
            }
        }
        for entry in calendarEntries where !entry.isCompleted && entry.kind != .event && entry.startDate < calendar.date(byAdding: .day, value: 1, to: day)! {
            deadlines.append(.init(id: "calendar:\(entry.id)", title: entry.title, date: entry.startDate, isOverdue: entry.startDate < day))
        }
        for assessment in assessments where assessment.earnedPoints == nil && assessment.dueDate < calendar.date(byAdding: .day, value: 1, to: day)! {
            deadlines.append(.init(id: "assessment:\(assessment.id)", title: assessment.title, date: assessment.dueDate, isOverdue: assessment.dueDate < day))
        }
        deadlines.sort { $0.date == $1.date ? $0.title < $1.title : $0.date < $1.date }

        return EveningReviewSummary(
            scheduledLessons: occurrences.count, heldLessons: held, attendedLessons: attended, cancelledLessons: cancelled,
            completedTasks: completedTasks, eligibleTasks: eligibleTasks, focusSeconds: focusSeconds,
            gymPlanned: planned.count, gymPlannedCompleted: planned.filter(\.isCompleted).count,
            gymLoggedCompleted: logged.count, deadlines: deadlines,
            overdueCount: deadlines.filter(\.isOverdue).count
        )
    }
}

struct EndOfDayReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var courses: [Course]
    @Query private var rules: [StudyScheduleRule]
    @Query private var attendance: [AttendanceRecord]
    @Query private var studyTasks: [StudyTask]
    @Query private var organizationTasks: [OrganizationTask]
    @Query private var calendarEntries: [CalendarEntry]
    @Query private var placements: [PlannedTaskPlacement]
    @Query private var focusSessions: [FocusSessionRecord]
    @Query private var plannedWorkouts: [PlannedWorkoutSession]
    @Query private var completedWorkouts: [WorkoutRecord]
    @Query private var assessments: [OBSAssessment]
    @AppStorage("eveningReview.lastAcknowledgedDay") private var lastAcknowledgedDay = ""

    let date: Date
    @State private var selectedForDate: OverdueReviewItem?
    @State private var pendingCancellation: OverdueReviewItem?
    @State private var chosenDate = Date.now
    @State private var error: String?

    private var occurrences: [LessonOccurrence] { DailyPlanAggregator.occurrences(rules: rules, on: date, courses: courses) }
    private var summary: EveningReviewSummary {
        EveningReviewService.make(date: date, occurrences: occurrences, attendance: attendance, studyTasks: studyTasks,
            organizationTasks: organizationTasks, calendarEntries: calendarEntries, placements: placements,
            focusSessions: focusSessions, plannedWorkouts: plannedWorkouts, completedWorkouts: completedWorkouts,
            assessments: assessments)
    }
    private var items: [OverdueReviewItem] {
        OverdueReviewService.items(studyTasks: studyTasks, organizationTasks: organizationTasks, reviewDate: date)
    }

    var body: some View {
        TerminalWindow {
            VStack(spacing: 0) {
                TerminalHeader(titleKey: "evening.title", subtitleKey: "evening.subtitle", onBack: { dismiss() })
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                            .foregroundStyle(TerminalTokens.phosphorMuted)
                        metrics
                        deadlines
                        overdueDecisions
                    }.padding(16)
                }
                if let error { Label(error, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error).padding(10) }
                HStack {
                    Text("evening.localOnly").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted)
                    Spacer()
                    Button("evening.acknowledge") {
                        lastAcknowledgedDay = EveningReviewAcknowledgement.dayKey(for: date)
                        dismiss()
                    }.buttonStyle(TerminalPrimaryButtonStyle()).keyboardShortcut(.return, modifiers: [])
                }.padding(12).background(TerminalTokens.surface.opacity(0.6))
            }
        }
        .frame(minWidth: 780, idealWidth: 900, minHeight: 620, idealHeight: 760)
        .sheet(item: $selectedForDate) { item in
            TerminalWindow {
                TerminalDialog(titleKey: "overdue.chooseDate") {
                    DatePicker("overdue.newDate", selection: $chosenDate, displayedComponents: .date)
                    HStack {
                        Spacer()
                        Button("action.cancel") { selectedForDate = nil }.buttonStyle(TerminalButtonStyle())
                        Button("action.save") { apply(.anotherDate, item, date: chosenDate); selectedForDate = nil }.buttonStyle(TerminalPrimaryButtonStyle())
                    }
                }.padding()
            }.frame(width: 500, height: 260)
        }
        .confirmationDialog("evening.cancel.confirm.title", isPresented: Binding(get: { pendingCancellation != nil }, set: { if !$0 { pendingCancellation = nil } })) {
            Button("overdue.cancelTask", role: .destructive) {
                if let item = pendingCancellation { apply(.cancel, item) }
                pendingCancellation = nil
            }
            Button("action.cancel", role: .cancel) { pendingCancellation = nil }
        } message: { Text("evening.cancel.confirm.message") }
        .accessibilityIdentifier("eveningReview.screen")
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 10) {
            metric("evening.lessons", "\(summary.attendedLessons)/\(summary.heldLessons)", "book.closed")
            metric("evening.scheduledLessons", "\(summary.scheduledLessons)", "calendar")
            metric("evening.cancelledLessons", "\(summary.cancelledLessons)", "nosign")
            metric("evening.tasks", "\(summary.completedTasks)/\(summary.eligibleTasks)", "checklist")
            metric("evening.focus", focusText(summary.focusSeconds), "timer")
            metric("evening.gym", "\(summary.gymPlannedCompleted)/\(summary.gymPlanned) · +\(summary.gymLoggedCompleted)", "figure.strengthtraining.traditional")
        }
    }

    private func metric(_ key: String, _ value: String, _ symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(LocalizedStringKey(key), systemImage: symbol).foregroundStyle(TerminalTokens.phosphorMuted)
            Text(value).font(.system(.title2, design: .monospaced, weight: .bold)).monospacedDigit()
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(TerminalTokens.surface.opacity(0.7)).overlay(Rectangle().stroke(TerminalTokens.border))
            .accessibilityElement(children: .combine)
    }

    private var deadlines: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("evening.deadlines").font(.headline)
                Spacer()
                Text(String(format: String(localized: "evening.overdueCount"), summary.overdueCount)).foregroundStyle(summary.overdueCount > 0 ? TerminalTokens.warning : TerminalTokens.phosphorMuted)
            }
            if summary.deadlines.isEmpty {
                Text("evening.deadlines.empty").foregroundStyle(TerminalTokens.phosphorMuted)
            } else {
                ForEach(summary.deadlines.prefix(8)) { item in
                    HStack {
                        Image(systemName: item.isOverdue ? "exclamationmark.triangle" : "calendar")
                        Text(item.title).lineLimit(1)
                        Spacer()
                        Text(item.date, style: .date).monospacedDigit()
                        if item.isOverdue { Text("evening.overdue.signal").font(.caption).foregroundStyle(TerminalTokens.warning) }
                    }
                }
            }
        }.padding(12).background(TerminalTokens.surface.opacity(0.55)).overlay(Rectangle().stroke(TerminalTokens.border))
    }

    private var overdueDecisions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("evening.decisions").font(.headline)
            Text("overdue.choiceRequired").font(.caption).foregroundStyle(TerminalTokens.warning)
            if items.isEmpty {
                Text("overdue.empty.message").foregroundStyle(TerminalTokens.phosphorMuted)
            } else {
                ForEach(items) { item in row(item) }
            }
        }
    }

    private func row(_ item: OverdueReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(item.title, systemImage: item.source == .study ? "book.closed" : "square.grid.2x2").fontWeight(.semibold)
                Spacer()
                Text(item.dueDate, style: .date).foregroundStyle(TerminalTokens.warning)
            }
            HStack {
                Button("overdue.tomorrow") { apply(.tomorrow, item) }.buttonStyle(TerminalButtonStyle())
                Button("overdue.anotherDate") {
                    chosenDate = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
                    selectedForDate = item
                }.buttonStyle(TerminalButtonStyle())
                Button("overdue.keep") { apply(.keepOverdue, item) }.buttonStyle(TerminalButtonStyle())
                Button("overdue.cancelTask") { pendingCancellation = item }.buttonStyle(TerminalButtonStyle())
            }
        }.padding(10).background(TerminalTokens.surface).overlay(Rectangle().stroke(TerminalTokens.border))
    }

    private func apply(_ decision: OverdueDecision, _ item: OverdueReviewItem, date targetDate: Date? = nil) {
        do {
            try OverdueReviewService.apply(decision, to: item, anotherDate: targetDate, studyTasks: studyTasks,
                organizationTasks: organizationTasks, reviewDate: date, context: context)
        } catch { self.error = error.localizedDescription }
    }

    private func focusText(_ seconds: Int) -> String {
        let hours = seconds / 3_600, minutes = seconds % 3_600 / 60
        return hours > 0 ? String(format: String(localized: "briefing.durationHoursMinutes"), hours, minutes) : String(format: String(localized: "briefing.durationMinutes"), minutes)
    }
}
