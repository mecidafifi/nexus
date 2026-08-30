import SwiftUI
import SwiftData

struct SemesterSetupView: View {
    let courses: [Course]
    let rules: [StudyScheduleRule]
    let attendance: [AttendanceRecord]
    let tasks: [StudyTask]
    let sessions: [StudySession]
    let universityCourses: [UniversityCourse]
    let assessments: [OBSAssessment]
    let edit: (UUID?) -> Void

    var body: some View {
        Group {
            if courses.isEmpty { TerminalEmptyState(titleKey: "semester.empty.title", messageKey: "semester.empty.message", actionKey: "semester.new", action: { edit(nil) }) }
            else { ScrollView { LazyVStack(spacing: 10) { ForEach(courses.sorted { $0.name < $1.name }) { courseCard($0) } }.padding(16) } }
        }
    }

    private func courseCard(_ course: Course) -> some View {
        let courseRules = rules.filter { $0.courseID == course.id && $0.isActive }.sorted {
            if $0.weekday == $1.weekday { return $0.startMinutes < $1.startMinutes }
            return $0.weekday < $1.weekday
        }
        let courseAttendance = attendance.filter { $0.courseID == course.id }
        let courseTasks = tasks.filter { $0.courseID == course.id }
        let minutes = sessions.filter { $0.courseID == course.id }.reduce(0) { $0 + max($1.durationMinutes, 0) }
        let universityIDs = Set(universityCourses.filter { $0.linkedStudyCourseID == course.id }.map(\.id))
        let exams = assessments.filter { universityIDs.contains($0.universityCourseID) }
        return Button { edit(course.id) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { VStack(alignment: .leading) { Text(course.name).font(.headline); Text([course.code, course.instructor, course.location].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); if let exam = course.examDate { Label { Text(exam, style: .date) } icon: { Image(systemName: "doc.text") } } }
                HStack(spacing: 18) {
                    metric("semester.metric.weekly", "\(courseRules.count)", "calendar.badge.clock")
                    metric("semester.metric.attendance", "\(courseAttendance.count)", "person.crop.circle.badge.checkmark")
                    metric("semester.metric.tasks", "\(courseTasks.count)", "checklist")
                    metric("semester.metric.exams", "\(exams.count)", "graduationcap")
                    metric("semester.metric.studyTime", String(format: String(localized: "format.minutes"), minutes), "timer")
                    metric("semester.metric.allowedAbsence", "\(course.allowedAbsenceCount)", "exclamationmark.triangle")
                }
                if !courseRules.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(courseRules) { rule in
                            HStack(alignment: .top, spacing: 7) {
                                Text("\(weekdayName(rule.weekday)) \(timeString(rule.startMinutes))–\(timeString(rule.startMinutes + rule.durationMinutes))")
                                    .font(.caption).monospacedDigit()
                                if let metadata = ScheduleRulePresentationPolicy.metadata(for: rule) {
                                    Label(metadata.displaySummary(linkedCourse: course), systemImage: "exclamationmark.triangle")
                                        .font(.caption2).foregroundStyle(TerminalTokens.warning)
                                } else if !rule.locationOverride.isEmpty {
                                    Text(rule.locationOverride).font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
                                }
                            }
                        }
                    }
                }
                Text("semester.notesLinkUnavailable").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.surface).overlay(Rectangle().stroke(TerminalTokens.border))
        }.buttonStyle(.plain)
    }
    private func metric(_ key: String, _ value: String, _ symbol: String) -> some View { VStack(alignment: .leading, spacing: 2) { Label(LocalizedStringKey(key), systemImage: symbol).font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted); Text(value).fontWeight(.semibold).monospacedDigit() } }
    private func weekdayName(_ value: Int) -> String { let names = Calendar.current.shortWeekdaySymbols; return names.indices.contains(value - 1) ? names[value - 1] : "\(value)" }
    private func timeString(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }
}

struct SemesterCourseEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("planning.conflictWarnings") private var conflictWarnings = true
    let course: Course?
    let allRules: [StudyScheduleRule]
    @State private var name: String; @State private var code: String; @State private var instructor: String; @State private var room: String
    @State private var semesterStart: Date; @State private var semesterEnd: Date; @State private var allowedAbsences: Int; @State private var hasExam: Bool; @State private var examDate: Date
    @State private var weekdays: Set<Int>; @State private var time: Date; @State private var duration: Int; @State private var error: String?; @State private var showConflict = false

    init(course: Course?, rules: [StudyScheduleRule]) {
        self.course = course; self.allRules = rules
        let calendar = Calendar.current; let existing = rules.filter { $0.courseID == course?.id && $0.isActive }; let first = existing.first
        _name = State(initialValue: course?.name ?? ""); _code = State(initialValue: course?.code ?? ""); _instructor = State(initialValue: course?.instructor ?? ""); _room = State(initialValue: course?.location ?? "")
        _semesterStart = State(initialValue: course?.semesterStart ?? .now); _semesterEnd = State(initialValue: course?.semesterEnd ?? calendar.date(byAdding: .month, value: 4, to: .now) ?? .now)
        _allowedAbsences = State(initialValue: course?.allowedAbsenceCount ?? 3); _hasExam = State(initialValue: course?.examDate != nil); _examDate = State(initialValue: course?.examDate ?? calendar.date(byAdding: .month, value: 3, to: .now) ?? .now)
        _weekdays = State(initialValue: Set(existing.map(\.weekday)))
        let day = calendar.startOfDay(for: .now); _time = State(initialValue: calendar.date(byAdding: .minute, value: first?.startMinutes ?? 540, to: day) ?? .now); _duration = State(initialValue: first?.durationMinutes ?? 50)
    }

    var body: some View {
        TerminalWindow { TerminalDialog(titleKey: course == nil ? "semester.editor.new" : "semester.editor.edit") {
            TerminalForm {
                Section("semester.section.course") { TextField("course.name", text: $name); TextField("course.code", text: $code); TextField("course.instructor", text: $instructor); TextField("course.location", text: $room); Stepper(value: $allowedAbsences, in: 0...50) { LabeledContent("semester.allowedAbsences", value: "\(allowedAbsences)") } }
                Section("semester.section.dates") { DatePicker("semester.start", selection: $semesterStart, displayedComponents: .date); DatePicker("semester.end", selection: $semesterEnd, displayedComponents: .date); Toggle("semester.hasExam", isOn: $hasExam); if hasExam { DatePicker("semester.examDate", selection: $examDate) } }
                Section("semester.section.weekly") {
                    HStack { ForEach(1...7, id: \.self) { day in Button(weekdayName(day)) { if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) } }.buttonStyle(TerminalButtonStyle()).background(weekdays.contains(day) ? TerminalTokens.phosphor.opacity(0.2) : Color.clear).accessibilityValue(weekdays.contains(day) ? Text("state.selected") : Text("state.default")) } }
                    DatePicker("semester.lessonTime", selection: $time, displayedComponents: .hourAndMinute)
                    Stepper(value: $duration, in: 10...360, step: 5) { LabeledContent("semester.duration", value: String(format: String(localized: "format.minutes"), duration)) }
                }
                Section("semester.conflict.section") { Text(LocalizedStringKey(conflictWarnings ? "semester.conflict.enabled" : "semester.conflict.disabled")).foregroundStyle(TerminalTokens.phosphorMuted) }
            }.frame(height: 540)
            if let error { Label(error, systemImage: "xmark.octagon").foregroundStyle(TerminalTokens.error) }
            HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { attemptSave() }.buttonStyle(TerminalPrimaryButtonStyle()) }
        }.padding() }.frame(width: 700, height: 740)
        .confirmationDialog("semester.conflict.title", isPresented: $showConflict) {
            Button("semester.conflict.findAnother") { findAnotherTime() }
            Button("semester.conflict.keep") { save(keepAnyway: true) }
            Button("action.cancel", role: .cancel) {}
        } message: { Text("semester.conflict.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in attemptSave() }
    }

    private var startMinutes: Int { let parts = Calendar.current.dateComponents([.hour, .minute], from: time); return (parts.hour ?? 0) * 60 + (parts.minute ?? 0) }
    private var otherSlots: [ScheduleSlot] { allRules.filter { $0.isActive && $0.courseID != course?.id }.map { ScheduleSlot(id: $0.id, weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes) } }
    private var proposedSlots: [ScheduleSlot] { weekdays.map { ScheduleSlot(id: UUID(), weekday: $0, startMinutes: startMinutes, durationMinutes: duration) } }
    private func attemptSave() { if conflictWarnings && proposedSlots.contains(where: { !ScheduleConflictService.conflicts($0, with: otherSlots).isEmpty }) { showConflict = true } else { save(keepAnyway: false) } }
    private func findAnotherTime() { let candidates = proposedSlots.compactMap { ScheduleConflictService.nextAvailableStart(for: $0, existing: otherSlots) }; guard let latest = candidates.max() else { error = String(localized: "semester.conflict.noSlot"); return }; let day = Calendar.current.startOfDay(for: time); time = Calendar.current.date(byAdding: .minute, value: latest, to: day) ?? time; error = String(localized: "semester.conflict.moved") }
    private func save(keepAnyway: Bool) { do { _ = try SemesterScheduleService.save(course: course, name: name, code: code, instructor: instructor, room: room, semesterStart: semesterStart, semesterEnd: semesterEnd, allowedAbsences: allowedAbsences, examDate: hasExam ? examDate : nil, weekdays: weekdays, startMinutes: startMinutes, durationMinutes: duration, existingRules: allRules, context: context); dismiss() } catch { self.error = error.localizedDescription } }
    private func weekdayName(_ day: Int) -> String { let names = Calendar.current.veryShortWeekdaySymbols; return names.indices.contains(day - 1) ? names[day - 1] : "\(day)" }
}
