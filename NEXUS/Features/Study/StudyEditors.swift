import SwiftUI
import SwiftData

private struct EditorActions: View {
    @Environment(\.dismiss) private var dismiss
    let save: () -> Void
    var body: some View {
        HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save", action: save).buttonStyle(TerminalPrimaryButtonStyle()) }
    }
}

struct CourseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let course: Course?
    @ObservedObject var viewModel: StudyViewModel
    let contextMessageKey: String?
    let onSaved: (() -> Void)?
    @State private var name: String
    @State private var code: String
    @State private var instructor: String
    @State private var location: String
    @State private var error: String?

    init(course: Course?, viewModel: StudyViewModel, contextMessageKey: String? = nil, onSaved: (() -> Void)? = nil) {
        self.course = course; self.viewModel = viewModel
        self.contextMessageKey = contextMessageKey; self.onSaved = onSaved
        _name = State(initialValue: course?.name ?? ""); _code = State(initialValue: course?.code ?? "")
        _instructor = State(initialValue: course?.instructor ?? ""); _location = State(initialValue: course?.location ?? "")
    }

    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: course == nil ? "editor.course.new" : "editor.course.edit") {
            if let contextMessageKey {
                Label(LocalizedStringKey(contextMessageKey), systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(TerminalTokens.phosphorMuted)
            }
            TerminalForm {
                TextField("course.name", text: $name).accessibilityIdentifier("courseEditor.name")
                TextField("course.code", text: $code)
                TextField("course.instructor", text: $instructor)
                TextField("course.location", text: $location)
            }.frame(height: 250)
            if let error { Text(error).foregroundStyle(TerminalTokens.error) }
            EditorActions(save: save)
        }.padding() }
        .frame(width: 520, height: 420)
        .accessibilityIdentifier("courseEditor.screen")
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() }
    }
    private func save() { do { try viewModel.saveCourse(course, name: name, code: code, instructor: instructor, location: location, context: context); onSaved?(); dismiss() } catch { self.error = error.localizedDescription } }
}

struct TaskEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: StudyTask?
    let courses: [Course]
    @ObservedObject var viewModel: StudyViewModel
    @State private var title: String
    @State private var details: String
    @State private var courseID: UUID?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var status: StudyTaskStatus
    @State private var priority: StudyTaskPriority
    @State private var estimatedMinutes: Int
    @State private var error: String?

    init(task: StudyTask?, courses: [Course], viewModel: StudyViewModel) {
        self.task = task; self.courses = courses; self.viewModel = viewModel
        _title = State(initialValue: task?.title ?? ""); _details = State(initialValue: task?.details ?? ""); _courseID = State(initialValue: task?.courseID)
        _hasDueDate = State(initialValue: task?.dueDate != nil); _dueDate = State(initialValue: task?.dueDate ?? .now)
        _status = State(initialValue: task?.status ?? .planned); _priority = State(initialValue: task?.priority ?? .normal); _estimatedMinutes = State(initialValue: task?.estimatedMinutes ?? 60)
    }

    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: task == nil ? "editor.task.new" : "editor.task.edit") {
            TerminalForm {
                TextField("task.title", text: $title)
                TextField("task.details", text: $details, axis: .vertical).lineLimit(3...6)
                coursePicker
                Picker("task.status", selection: $status) { ForEach(StudyTaskStatus.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }
                Picker("task.priority", selection: $priority) { ForEach(StudyTaskPriority.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }
                Stepper(value: $estimatedMinutes, in: 0...600, step: 15) { LabeledContent("task.estimate", value: String(format: String(localized: "format.minutes"), estimatedMinutes)) }
                Toggle("task.hasDueDate", isOn: $hasDueDate)
                if hasDueDate { DatePicker("task.dueDate", selection: $dueDate) }
                if task?.externalCalendarEventIdentifier != nil { Label("task.calendarLinked", systemImage: "calendar.badge.checkmark").foregroundStyle(TerminalTokens.success) }
                else { Text("task.calendarFuture").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }
            }.frame(height: 450)
            if let error { Text(error).foregroundStyle(TerminalTokens.error) }
            EditorActions(save: save)
        }.padding() }
        .frame(width: 600, height: 650)
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() }
    }

    private var coursePicker: some View { Picker("task.course", selection: $courseID) { Text("study.unassigned").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } } }
    private func save() { do { try viewModel.saveTask(task, title: title, details: details, courseID: courseID, hasDueDate: hasDueDate, dueDate: dueDate, status: status, priority: priority, estimatedMinutes: estimatedMinutes, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}

struct GoalEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let goal: StudyGoal?
    let courses: [Course]
    @ObservedObject var viewModel: StudyViewModel
    @State private var title: String
    @State private var courseID: UUID?
    @State private var targetMinutes: Int
    @State private var period: GoalPeriod
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var error: String?

    init(goal: StudyGoal?, courses: [Course], viewModel: StudyViewModel) {
        self.goal = goal; self.courses = courses; self.viewModel = viewModel
        _title = State(initialValue: goal?.title ?? ""); _courseID = State(initialValue: goal?.courseID); _targetMinutes = State(initialValue: goal?.targetMinutes ?? 300)
        _period = State(initialValue: goal?.period ?? .weekly); _startDate = State(initialValue: goal?.startDate ?? .now)
        _endDate = State(initialValue: goal?.endDate ?? (Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now))
    }
    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: goal == nil ? "editor.goal.new" : "editor.goal.edit") {
            TerminalForm {
                TextField("goal.title", text: $title)
                Picker("goal.course", selection: $courseID) { Text("study.allCourses").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                Picker("goal.period", selection: $period) { ForEach(GoalPeriod.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }
                Stepper(value: $targetMinutes, in: 15...10000, step: 15) { LabeledContent("goal.target", value: String(format: String(localized: "format.minutes"), targetMinutes)) }
                DatePicker("goal.start", selection: $startDate, displayedComponents: .date)
                DatePicker("goal.end", selection: $endDate, displayedComponents: .date)
            }.frame(height: 350)
            if let error { Text(error).foregroundStyle(TerminalTokens.error) }
            EditorActions(save: save)
        }.padding() }.frame(width: 560, height: 540)
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() }
    }
    private func save() { do { try viewModel.saveGoal(goal, title: title, courseID: courseID, targetMinutes: targetMinutes, period: period, startDate: startDate, endDate: endDate, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}

struct SessionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let session: StudySession?
    let courses: [Course]
    @ObservedObject var viewModel: StudyViewModel
    @State private var courseID: UUID?
    @State private var startedAt: Date
    @State private var durationMinutes: Int
    @State private var note: String
    @State private var error: String?

    init(session: StudySession?, courses: [Course], viewModel: StudyViewModel) {
        self.session = session; self.courses = courses; self.viewModel = viewModel
        _courseID = State(initialValue: session?.courseID); _startedAt = State(initialValue: session?.startedAt ?? .now)
        _durationMinutes = State(initialValue: session?.durationMinutes ?? 45); _note = State(initialValue: session?.note ?? "")
    }
    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: session == nil ? "editor.session.new" : "editor.session.edit") {
            TerminalForm {
                Picker("session.course", selection: $courseID) { Text("study.unassigned").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                DatePicker("session.startedAt", selection: $startedAt)
                Stepper(value: $durationMinutes, in: 5...720, step: 5) { LabeledContent("session.duration", value: String(format: String(localized: "format.minutes"), durationMinutes)) }
                TextField("session.note", text: $note, axis: .vertical).lineLimit(3...6)
            }.frame(height: 280)
            if let error { Text(error).foregroundStyle(TerminalTokens.error) }
            EditorActions(save: save)
        }.padding() }.frame(width: 560, height: 470)
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() }
    }
    private func save() { do { try viewModel.saveSession(session, courseID: courseID, startedAt: startedAt, durationMinutes: durationMinutes, note: note, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}
