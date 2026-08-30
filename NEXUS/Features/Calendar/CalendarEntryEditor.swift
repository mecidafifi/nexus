import SwiftUI
import SwiftData

struct CalendarEntryEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: CalendarEntry?
    let studyTasks: [StudyTask]
    let courses: [Course]
    @ObservedObject var viewModel: CalendarViewModel
    @State private var title: String
    @State private var details: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var kind: CalendarEntryKind
    @State private var isCompleted: Bool
    @State private var hasReminder: Bool
    @State private var reminderDate: Date
    @State private var relatedRecordID: UUID?
    @State private var courseID: UUID?
    @State private var error: String?

    init(entry: CalendarEntry?, initialDate: Date, studyTasks: [StudyTask], courses: [Course], viewModel: CalendarViewModel) {
        self.entry = entry; self.studyTasks = studyTasks; self.courses = courses; self.viewModel = viewModel
        let start = entry?.startDate ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: initialDate) ?? initialDate
        _title = State(initialValue: entry?.title ?? ""); _details = State(initialValue: entry?.details ?? ""); _startDate = State(initialValue: start); _endDate = State(initialValue: entry?.endDate ?? start.addingTimeInterval(3600)); _isAllDay = State(initialValue: entry?.isAllDay ?? false); _kind = State(initialValue: entry?.kind ?? .event); _isCompleted = State(initialValue: entry?.isCompleted ?? false); _hasReminder = State(initialValue: entry?.reminderDate != nil); _reminderDate = State(initialValue: entry?.reminderDate ?? start.addingTimeInterval(-900)); _relatedRecordID = State(initialValue: entry?.relatedRecordID); _courseID = State(initialValue: entry?.courseID)
    }

    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: entry == nil ? "calendar.editor.new" : "calendar.editor.edit") {
            TerminalForm {
                TextField("calendar.title", text: $title)
                TextField("calendar.details", text: $details, axis: .vertical).lineLimit(2...5)
                Picker("calendar.kind", selection: $kind) { ForEach(CalendarEntryKind.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }
                Toggle("calendar.allDay", isOn: $isAllDay)
                DatePicker("calendar.start", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                DatePicker("calendar.end", selection: $endDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                if kind == .task { Toggle("calendar.completed", isOn: $isCompleted) }
                Picker("calendar.course", selection: $courseID) { Text("study.unassigned").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                Picker("calendar.studyTask", selection: $relatedRecordID) { Text("calendar.noStudyTask").tag(UUID?.none); ForEach(studyTasks) { Text($0.title).tag(Optional($0.id)) } }
                Toggle("calendar.hasReminder", isOn: $hasReminder)
                if hasReminder { DatePicker("calendar.reminderDate", selection: $reminderDate); Text("calendar.notification.notRequested").font(.caption).foregroundStyle(TerminalTokens.warning) }
            }.frame(height: 485)
            if let error { Text(error).foregroundStyle(TerminalTokens.error) }
            HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) }
        }.padding() }.frame(width: 610, height: 670)
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() }
    }

    private func save() { do { try viewModel.save(entry, title: title, details: details, startDate: startDate, endDate: endDate, isAllDay: isAllDay, kind: kind, isCompleted: isCompleted, hasReminder: hasReminder, reminderDate: reminderDate, relatedRecordID: relatedRecordID, courseID: courseID, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}

struct ReminderSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("calendar.reminderNotificationsWanted") private var wanted = false
    var body: some View { TerminalWindow { TerminalDialog(titleKey: "calendar.reminders.settings") {
        Label("calendar.reminders.internal", systemImage: "bell.badge").font(.headline)
        Text("calendar.reminders.explanation").foregroundStyle(TerminalTokens.phosphorMuted)
        Toggle("calendar.reminders.optIn", isOn: $wanted)
        Text("calendar.reminders.noPermission").font(.caption).foregroundStyle(TerminalTokens.warning)
        HStack { Spacer(); Button("action.done") { dismiss() }.buttonStyle(TerminalPrimaryButtonStyle()) }
    }.padding() }.frame(width: 540, height: 330) }
}
