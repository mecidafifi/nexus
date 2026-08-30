import SwiftUI
import SwiftData

struct StudyView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var courses: [Course]
    @Query private var tasks: [StudyTask]
    @Query private var goals: [StudyGoal]
    @Query private var sessions: [StudySession]
    @Query private var focusSessions: [FocusSessionRecord]
    @Query private var scheduleRules: [StudyScheduleRule]
    @Query private var attendance: [AttendanceRecord]
    @Query private var universityCourses: [UniversityCourse]
    @Query private var assessments: [OBSAssessment]
    @StateObject private var viewModel = StudyViewModel()
    @State private var editor: StudyEditor?
    @State private var deletion: DeleteTarget?
    @State private var showBackup = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeader(titleKey: "route.study", subtitleKey: "study.subtitle", onBack: appState.goHome)
            HStack(spacing: 0) {
                sidebar
                Divider().overlay(TerminalTokens.border)
                VStack(spacing: 0) {
                    toolbar
                    content
                }
            }
            if let error = viewModel.errorMessage {
                HStack { Image(systemName: "xmark.octagon"); Text(error); Spacer() }.foregroundStyle(TerminalTokens.error).padding(.horizontal, 12).frame(height: 28).background(TerminalTokens.surface)
            } else { TerminalStatusBar(messageKey: viewModel.statusMessageKey, kind: viewModel.statusMessageKey == "status.saved" ? .success : .neutral) }
        }
        .sheet(item: $editor) { editorView($0) }
        .sheet(isPresented: $showBackup) { BackupView() }
        .confirmationDialog("delete.confirm.title", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("action.delete", role: .destructive) { performDelete() }
            Button("action.cancel", role: .cancel) { deletion = nil }
        } message: { Text("delete.confirm.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in createNew() }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .onAppear { consumeRequestedSection() }
        .onChange(of: appState.requestedStudySection) { _, _ in consumeRequestedSection() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(StudySection.allCases) { section in
                Button { viewModel.section = section } label: {
                    HStack { Image(systemName: section.symbol).frame(width: 20); Text(LocalizedStringKey(section.titleKey)); Spacer() }
                        .padding(.horizontal, 12).frame(height: 40).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(viewModel.section == section ? TerminalTokens.phosphor.opacity(0.12) : .clear)
                .overlay(alignment: .leading) { if viewModel.section == section { Rectangle().fill(TerminalTokens.phosphor).frame(width: 3) } }
            }
            Spacer()
            Button { showBackup = true } label: { Label("backup.title", systemImage: "externaldrive") }.buttonStyle(TerminalButtonStyle()).padding(10)
        }.frame(width: 190).background(TerminalTokens.surface.opacity(0.45))
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
            TextField("study.search", text: $viewModel.searchText).textFieldStyle(.plain).focused($searchFocused)
            if viewModel.section == .tasks {
                Picker("study.filter", selection: $viewModel.taskStatusFilter) {
                    Text("filter.all").tag(StudyTaskStatus?.none)
                    ForEach(StudyTaskStatus.allCases) { Text(LocalizedStringKey($0.titleKey)).tag(Optional($0)) }
                }.frame(width: 145)
                Picker("study.sort", selection: $viewModel.sort) {
                    ForEach(StudySort.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
                }.frame(width: 140)
            }
            Button(action: createNew) { Label("action.new", systemImage: "plus") }.buttonStyle(TerminalPrimaryButtonStyle())
        }.padding(.horizontal, 12).frame(height: 52).background(TerminalTokens.surface.opacity(0.3))
    }

    @ViewBuilder private var content: some View {
        switch viewModel.section {
        case .overview: StudyOverviewView(courses: courses, tasks: tasks, goals: goals, sessions: sessions, focusSessions: focusSessions, viewModel: viewModel) {
            appState.startFocus(FocusRequest(source: .studyContext, title: String(localized: "focus.freeStudy"), plannedDurationSeconds: 45 * 60))
        }
        case .semesterSetup: SemesterSetupView(courses: courses, rules: scheduleRules, attendance: attendance, tasks: tasks, sessions: sessions, universityCourses: universityCourses, assessments: assessments, edit: { editor = StudyEditor(kind: .semester, objectID: $0) })
        case .courses: courseList
        case .tasks: taskList
        case .goals: goalList
        case .sessions: sessionList
        }
    }

    private var courseList: some View {
        Group {
            let rows = viewModel.filteredCourses(courses)
            if rows.isEmpty { TerminalEmptyState(titleKey: "empty.courses.title", messageKey: "empty.courses.message", actionKey: "action.newCourse", action: { editor = .init(kind: .course) }) }
            else { ScrollView { TerminalTable { ForEach(rows) { course in
                Button { editor = StudyEditor(kind: .course, objectID: course.id) } label: { TerminalTableRow { HStack { VStack(alignment: .leading) { Text(course.name).fontWeight(.semibold); Text(course.code.isEmpty ? String(localized: "course.noCode") : course.code).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); Text(course.instructor) } } }.buttonStyle(.plain).contextMenu { editDeleteButtons(.course, id: course.id) }
            } }.padding(16) } }
        }
    }

    private var taskList: some View {
        Group {
            let rows = viewModel.filteredTasks(tasks)
            if rows.isEmpty { TerminalEmptyState(titleKey: "empty.tasks.title", messageKey: "empty.tasks.message", actionKey: "action.newTask", action: { editor = .init(kind: .task) }) }
            else { ScrollView { TerminalTable { ForEach(rows) { task in
                TerminalTableRow { HStack {
                    Button { editor = StudyEditor(kind: .task, objectID: task.id) } label: { HStack { Image(systemName: task.status == .completed ? "checkmark.square.fill" : "square").accessibilityLabel(Text(LocalizedStringKey(task.status.titleKey))); VStack(alignment: .leading) { Text(task.title).strikethrough(task.status == .completed); Text(viewModel.courseName(for: task.courseID, courses: courses)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); if let due = task.dueDate { Text(due, style: .date).monospacedDigit() }; Text(LocalizedStringKey(task.priority.titleKey)).font(.caption) } }.buttonStyle(.plain).contextMenu { editDeleteButtons(.task, id: task.id) }
                    Button { startFocus(task) } label: { Image(systemName: "timer") }.buttonStyle(TerminalButtonStyle()).accessibilityLabel(Text("focus.start")).disabled(task.status == .completed || task.status == .cancelled)
                } }
            } }.padding(16) } }
        }
    }

    private var goalList: some View {
        Group {
            let rows = viewModel.filteredGoals(goals)
            if rows.isEmpty { TerminalEmptyState(titleKey: "empty.goals.title", messageKey: "empty.goals.message", actionKey: "action.newGoal", action: { editor = .init(kind: .goal) }) }
            else { ScrollView { TerminalTable { ForEach(rows) { goal in
                Button { editor = StudyEditor(kind: .goal, objectID: goal.id) } label: { TerminalTableRow { VStack(alignment: .leading, spacing: 8) { HStack { Text(goal.title).fontWeight(.semibold); Spacer(); Text(goal.endDate, style: .date) }; TerminalProgressBar(value: viewModel.goalProgress(goal, sessions: sessions, focusSessions: focusSessions)) } } }.buttonStyle(.plain).contextMenu { editDeleteButtons(.goal, id: goal.id) }
            } }.padding(16) } }
        }
    }

    private var sessionList: some View {
        Group {
            let rows = viewModel.filteredSessions(sessions)
            if rows.isEmpty { TerminalEmptyState(titleKey: "empty.sessions.title", messageKey: "empty.sessions.message", actionKey: "action.newSession", action: { editor = .init(kind: .session) }) }
            else { ScrollView { TerminalTable { ForEach(rows) { session in
                Button { editor = StudyEditor(kind: .session, objectID: session.id) } label: { TerminalTableRow { HStack { VStack(alignment: .leading) { Text(viewModel.courseName(for: session.courseID, courses: courses)).fontWeight(.semibold); Text(session.note).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); Text(session.startedAt, style: .date); Text(String(format: String(localized: "format.minutes"), session.durationMinutes)).monospacedDigit() } } }.buttonStyle(.plain).contextMenu { editDeleteButtons(.session, id: session.id) }
            } }.padding(16) } }
        }
    }

    @ViewBuilder private func editDeleteButtons(_ kind: StudyEditor.Kind, id: UUID) -> some View {
        Button("action.edit") { editor = StudyEditor(kind: kind, objectID: id) }
        Button("action.delete", role: .destructive) { deletion = DeleteTarget(kind: kind, id: id) }
    }

    private func createNew() {
        let kind: StudyEditor.Kind = switch viewModel.section { case .semesterSetup: .semester; case .courses: .course; case .goals: .goal; case .sessions: .session; default: .task }
        editor = StudyEditor(kind: kind)
    }

    private func consumeRequestedSection() {
        guard let requested = appState.requestedStudySection else { return }
        viewModel.section = requested
        appState.requestedStudySection = nil
    }

    private func startFocus(_ task: StudyTask) {
        appState.startFocus(FocusRequest(source: .studyTask, sourceRecordID: task.id, courseID: task.courseID,
                                         title: task.title, plannedDurationSeconds: max(task.estimatedMinutes, 10) * 60))
    }

    @ViewBuilder private func editorView(_ value: StudyEditor) -> some View {
        switch value.kind {
        case .semester: SemesterCourseEditor(course: courses.first { $0.id == value.objectID }, rules: scheduleRules)
        case .course: CourseEditorView(course: courses.first { $0.id == value.objectID }, viewModel: viewModel)
        case .task: TaskEditorView(task: tasks.first { $0.id == value.objectID }, courses: courses, viewModel: viewModel)
        case .goal: GoalEditorView(goal: goals.first { $0.id == value.objectID }, courses: courses, viewModel: viewModel)
        case .session: SessionEditorView(session: sessions.first { $0.id == value.objectID }, courses: courses, viewModel: viewModel)
        }
    }

    private func performDelete() {
        guard let deletion else { return }
        do {
            switch deletion.kind {
            case .semester: break
            case .course: if let value = courses.first(where: { $0.id == deletion.id }) { try viewModel.delete(value, context: context) }
            case .task: if let value = tasks.first(where: { $0.id == deletion.id }) { try viewModel.delete(value, context: context) }
            case .goal: if let value = goals.first(where: { $0.id == deletion.id }) { try viewModel.delete(value, context: context) }
            case .session: if let value = sessions.first(where: { $0.id == deletion.id }) { try viewModel.delete(value, context: context) }
            }
        } catch { viewModel.errorMessage = error.localizedDescription }
        self.deletion = nil
    }
}

private struct StudyEditor: Identifiable {
    enum Kind { case semester, course, task, goal, session }
    let id = UUID(); let kind: Kind; var objectID: UUID?
}
private struct DeleteTarget { let kind: StudyEditor.Kind; let id: UUID }
