import SwiftUI
import SwiftData

struct AttendanceView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var records: [AttendanceRecord]
    @Query(sort: \Course.name) private var courses: [Course]
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var editorRecordID: UUID?
    @State private var creating = false
    @State private var deletion: AttendanceRecord?
    @FocusState private var searchFocused: Bool

    private var rows: [AttendanceRecord] { viewModel.filtered(records, courses: courses) }
    private var activeSummary: AttendanceSummary { viewModel.summary(records, courseID: viewModel.selectedCourseID) }
    private var allowedAbsences: Int? { viewModel.selectedCourseID.flatMap { id in courses.first { $0.id == id }?.allowedAbsenceCount } }

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeader(titleKey: "route.attendance", subtitleKey: "attendance.subtitle", onBack: appState.goHome)
            HStack(spacing: 0) {
                courseSidebar
                Divider().overlay(TerminalTokens.border)
                VStack(spacing: 0) { toolbar; summaryPanel; history }
            }
            if let error = viewModel.errorMessage { HStack { Image(systemName: "xmark.octagon"); Text(error); Spacer() }.foregroundStyle(TerminalTokens.error).padding(.horizontal, 12).frame(height: 28).background(TerminalTokens.surface) }
            else { TerminalStatusBar(messageKey: viewModel.statusMessageKey, kind: allowedAbsences.map { viewModel.isAbsenceDanger(activeSummary, allowed: $0) } == true ? .warning : .neutral) }
        }
        .sheet(isPresented: $creating) { AttendanceEditor(record: nil, defaultCourseID: viewModel.selectedCourseID, courses: courses, viewModel: viewModel) }
        .sheet(item: $editorRecordID) { id in AttendanceEditor(record: records.first { $0.id == id }, defaultCourseID: nil, courses: courses, viewModel: viewModel) }
        .confirmationDialog("delete.confirm.title", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) { Button("action.delete", role: .destructive) { deleteRecord() }; Button("action.cancel", role: .cancel) { deletion = nil } } message: { Text("delete.confirm.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in creating = true }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .accessibilityIdentifier("attendance.screen")
    }

    private var courseSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { viewModel.selectedCourseID = nil } label: { HStack { Image(systemName: "chart.pie"); Text("attendance.allCourses"); Spacer(); Text("\(records.count)") } }.buttonStyle(.plain).padding(10).background(viewModel.selectedCourseID == nil ? TerminalTokens.phosphor.opacity(0.12) : .clear)
            Text("attendance.courses").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).padding(.horizontal, 10).padding(.top, 10)
            ForEach(courses) { course in
                let summary = viewModel.summary(records, courseID: course.id)
                Button { viewModel.selectedCourseID = course.id } label: { VStack(alignment: .leading, spacing: 3) { HStack { Image(systemName: "book.closed"); Text(course.name).lineLimit(1); Spacer() }; Text(summary.percentage.map { String(format: String(localized: "attendance.percent.format"), $0) } ?? String(localized: "attendance.noData")).font(.caption).foregroundStyle(viewModel.isAbsenceDanger(summary, allowed: course.allowedAbsenceCount) ? TerminalTokens.warning : TerminalTokens.phosphorMuted) } }.buttonStyle(.plain).padding(10).background(viewModel.selectedCourseID == course.id ? TerminalTokens.phosphor.opacity(0.12) : .clear)
            }
            Spacer()
            Text("attendance.allowedConfiguredPerCourse").font(.caption2).foregroundStyle(TerminalTokens.phosphorMuted).padding(10)
        }.frame(width: 220).background(TerminalTokens.surface.opacity(0.45))
    }

    private var toolbar: some View {
        HStack { Image(systemName: "magnifyingglass"); TextField("attendance.search", text: $viewModel.searchText).textFieldStyle(.plain).focused($searchFocused); Picker("attendance.filter", selection: $viewModel.statusFilter) { Text("filter.all").tag(AttendanceStatus?.none); ForEach(AttendanceStatus.allCases) { Text(LocalizedStringKey($0.titleKey)).tag(Optional($0)) } }.frame(width: 135); Picker("attendance.sort", selection: $viewModel.sort) { ForEach(AttendanceSort.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }.frame(width: 130); Button { creating = true } label: { Label("action.new", systemImage: "plus") }.buttonStyle(TerminalPrimaryButtonStyle()).disabled(courses.isEmpty) }.padding(.horizontal, 12).frame(height: 52).background(TerminalTokens.surface.opacity(0.35))
    }

    private var summaryPanel: some View {
        VStack(spacing: 10) {
            HStack { metric("attendance.metric.held", activeSummary.held); metric("attendance.metric.attended", activeSummary.attended); metric("attendance.status.absent", activeSummary.absent); metric("attendance.status.cancelled", activeSummary.cancelled); metric("attendance.metric.remaining", allowedAbsences.map { viewModel.remainingAbsences(activeSummary, allowed: $0) } ?? 0); VStack(alignment: .leading) { Text("attendance.metric.rate").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted); Text(activeSummary.percentage.map { String(format: String(localized: "attendance.percent.format"), $0) } ?? "—").font(.title2).fontWeight(.bold).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading) }
            if let allowedAbsences, viewModel.isAbsenceDanger(activeSummary, allowed: allowedAbsences) { Label("attendance.warning.absenceDanger", systemImage: "exclamationmark.triangle.fill").foregroundStyle(TerminalTokens.warning).frame(maxWidth: .infinity, alignment: .leading).accessibilityLabel(Text("attendance.warning.accessibility")) }
            Text("attendance.calculation.occurrenceHelp").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(12).background(TerminalTokens.surface).overlay(RoundedRectangle(cornerRadius: 3).stroke(TerminalTokens.border))
    }

    private func metric(_ key: String, _ value: Int) -> some View { VStack(alignment: .leading) { Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted); Text("\(value)").font(.title2).fontWeight(.bold).monospacedDigit() }.frame(maxWidth: .infinity, alignment: .leading) }

    private var history: some View {
        Group { if courses.isEmpty { TerminalEmptyState(titleKey: "attendance.noCourses.title", messageKey: "attendance.noCourses.message") } else if rows.isEmpty { TerminalEmptyState(titleKey: "attendance.empty.title", messageKey: "attendance.empty.message", actionKey: "action.new", action: { creating = true }) } else { List { ForEach(rows) { record in
            Button { editorRecordID = record.id } label: { HStack { Image(systemName: record.status.symbol).frame(width: 22).accessibilityLabel(Text(LocalizedStringKey(record.status.titleKey))); VStack(alignment: .leading) { Text(courses.first(where: { $0.id == record.courseID })?.name ?? String(localized: "study.unassigned")).fontWeight(.semibold); Text(record.note).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(1) }; Spacer(); Text(LocalizedStringKey(record.status.titleKey)); Text(record.date, style: .date).monospacedDigit() }.padding(.vertical, 5) }.buttonStyle(.plain).contextMenu { Button("action.edit") { editorRecordID = record.id }; Button("action.delete", role: .destructive) { deletion = record } }
        } }.listStyle(.inset).scrollContentBackground(.hidden) } }
    }

    private func deleteRecord() { guard let deletion else { return }; do { try viewModel.delete(deletion, context: context) } catch { viewModel.errorMessage = error.localizedDescription }; self.deletion = nil }
}

private struct AttendanceEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let record: AttendanceRecord?
    let courses: [Course]
    @ObservedObject var viewModel: AttendanceViewModel
    @State private var courseID: UUID?
    @State private var date: Date
    @State private var status: AttendanceStatus
    @State private var note: String
    @State private var error: String?

    init(record: AttendanceRecord?, defaultCourseID: UUID?, courses: [Course], viewModel: AttendanceViewModel) { self.record = record; self.courses = courses; self.viewModel = viewModel; _courseID = State(initialValue: record?.courseID ?? defaultCourseID ?? courses.first?.id); _date = State(initialValue: record?.date ?? .now); _status = State(initialValue: record?.status ?? .present); _note = State(initialValue: record?.note ?? "") }
    var body: some View { TerminalWindow { TerminalDialog(titleKey: record == nil ? "attendance.editor.new" : "attendance.editor.edit") { TerminalForm { Picker("attendance.course", selection: $courseID) { Text("attendance.selectCourse").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }; DatePicker("attendance.date", selection: $date); Picker("attendance.status", selection: $status) { ForEach(AttendanceStatus.allCases) { Label(LocalizedStringKey($0.titleKey), systemImage: $0.symbol).tag($0) } }; TextField("attendance.note", text: $note, axis: .vertical).lineLimit(2...5) }.frame(height: 280); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }.padding() }.frame(width: 540, height: 460).onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() } }
    private func save() { do { try viewModel.save(record, courseID: courseID, date: date, status: status, note: note, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}
