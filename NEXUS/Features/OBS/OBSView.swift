import SwiftUI
import SwiftData

struct OBSView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var universityCourses: [UniversityCourse]
    @Query private var assessments: [OBSAssessment]
    @Query private var gradeBands: [GradeScaleBand]
    @Query(sort: \Course.name) private var studyCourses: [Course]
    @StateObject private var viewModel = OBSViewModel()
    @State private var editor: OBSEditor?
    @State private var deletion: OBSDeletion?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeader(titleKey: "route.obs", subtitleKey: "obs.subtitle", onBack: appState.goHome)
            Label("obs.manual.banner", systemImage: "lock.shield").font(.caption).foregroundStyle(TerminalTokens.warning).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.warning.opacity(0.08)).accessibilityLabel(Text("obs.manual.accessibility"))
            HStack(spacing: 0) { sidebar; Divider().overlay(TerminalTokens.border); VStack(spacing: 0) { toolbar; content } }
            if let error = viewModel.errorMessage { HStack { Image(systemName: "xmark.octagon"); Text(error); Spacer() }.foregroundStyle(TerminalTokens.error).padding(.horizontal, 12).frame(height: 28).background(TerminalTokens.surface) } else { TerminalStatusBar(messageKey: viewModel.statusMessageKey) }
        }
        .sheet(item: $editor) { editorView($0) }
        .confirmationDialog("delete.confirm.title", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) { Button("action.delete", role: .destructive) { performDelete() }; Button("action.cancel", role: .cancel) { deletion = nil } } message: { Text("delete.confirm.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in createNew() }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .accessibilityIdentifier("obs.screen")
    }

    private var sidebar: some View { VStack(spacing: 4) { ForEach(OBSSection.allCases) { section in Button { viewModel.section = section } label: { HStack { Image(systemName: section.symbol).frame(width: 20); Text(LocalizedStringKey(section.titleKey)); Spacer() }.padding(10) }.buttonStyle(.plain).background(viewModel.section == section ? TerminalTokens.phosphor.opacity(0.12) : .clear).overlay(alignment: .leading) { if viewModel.section == section { Rectangle().fill(TerminalTokens.phosphor).frame(width: 3) } } }; Divider().overlay(TerminalTokens.border); Button { viewModel.selectedCourseID = nil } label: { Text("obs.allCourses").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).padding(8); ForEach(universityCourses.sorted { $0.name < $1.name }) { course in Button { viewModel.selectedCourseID = course.id } label: { VStack(alignment: .leading) { Text(course.name).lineLimit(1); Text(course.code).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }.frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).padding(8).background(viewModel.selectedCourseID == course.id ? TerminalTokens.phosphor.opacity(0.12) : .clear) }; Spacer() }.frame(width: 205).background(TerminalTokens.surface.opacity(0.45)) }

    private var toolbar: some View { HStack { Image(systemName: "magnifyingglass"); TextField("obs.search", text: $viewModel.searchText).textFieldStyle(.plain).focused($searchFocused); if viewModel.section == .assessments { Picker("obs.kind.filter", selection: $viewModel.kindFilter) { Text("filter.all").tag(AssessmentKind?.none); ForEach(AssessmentKind.allCases) { Text(LocalizedStringKey($0.titleKey)).tag(Optional($0)) } }.frame(width: 145); Picker("obs.sort", selection: $viewModel.sort) { ForEach(OBSSort.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }.frame(width: 130) }; Button(action: createNew) { Label("action.new", systemImage: "plus") }.buttonStyle(TerminalPrimaryButtonStyle()) }.padding(.horizontal, 12).frame(height: 52).background(TerminalTokens.surface.opacity(0.35)) }

    @ViewBuilder private var content: some View { switch viewModel.section { case .overview: overview; case .courses: courseList; case .assessments: assessmentList; case .gradeScale: scaleList } }

    private var overview: some View {
        let overall = viewModel.weightedOverall(courses: universityCourses, assessments: assessments)
        let gpa = viewModel.gpa(courses: universityCourses, assessments: assessments, bands: gradeBands)
        let upcoming = viewModel.upcoming(assessments)
        return ScrollView { VStack(alignment: .leading, spacing: 14) { HStack { stat("obs.metric.courses", "\(universityCourses.count)"); stat("obs.metric.average", overall.map { String(format: "%.2f%%", $0) } ?? "—"); stat("obs.metric.gpa", gpa.map { String(format: "%.2f", $0.gpa) } ?? "—"); stat("obs.metric.upcoming", "\(upcoming.count)") }; if gradeBands.isEmpty { Label("obs.scale.required", systemImage: "exclamationmark.triangle").foregroundStyle(TerminalTokens.warning).terminalOBSPanel() }; Text("obs.upcoming").font(.headline); if upcoming.isEmpty { Text("obs.upcoming.empty").foregroundStyle(TerminalTokens.phosphorMuted).terminalOBSPanel() } else { ForEach(upcoming.prefix(6)) { item in HStack { Image(systemName: "calendar"); VStack(alignment: .leading) { Text(item.title); Text(courseName(item.universityCourseID)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); Text(item.dueDate, style: .date) }.terminalOBSPanel() } }; Text("obs.gradeUpdates").font(.headline); ForEach(assessments.filter { $0.earnedPoints != nil }.sorted { $0.updatedAt > $1.updatedAt }.prefix(5)) { item in HStack { Text(item.title); Spacer(); Text(String(format: String(localized: "obs.score.format"), item.earnedPoints!, item.maximumPoints)).monospacedDigit() }.terminalOBSPanel() } }.padding(16) }
    }

    private func stat(_ key: String, _ value: String) -> some View { VStack(alignment: .leading) { Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted); Text(value).font(.title2).fontWeight(.bold).monospacedDigit() }.terminalOBSPanel() }

    private var courseList: some View { Group { let rows = viewModel.filteredCourses(universityCourses); if rows.isEmpty { TerminalEmptyState(titleKey: "obs.courses.empty.title", messageKey: "obs.courses.empty.message", actionKey: "obs.course.new", action: { editor = .course(nil) }) } else { List { ForEach(rows) { course in Button { editor = .course(course.id) } label: { HStack { VStack(alignment: .leading) { Text(course.name).fontWeight(.semibold); Text("\(course.code) • \(course.semester)").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); Text(String(format: String(localized: "obs.credits.format"), course.creditHours)); Text(viewModel.courseAverage(courseID: course.id, assessments: assessments).map { String(format: "%.1f%%", $0) } ?? "—").monospacedDigit() }.padding(.vertical, 5) }.buttonStyle(.plain).contextMenu { Button("action.edit") { editor = .course(course.id) }; Button("action.delete", role: .destructive) { deletion = .course(course.id) } } } }.listStyle(.inset).scrollContentBackground(.hidden) } } }

    private var assessmentList: some View { Group { let rows = viewModel.filteredAssessments(assessments, courses: universityCourses); if rows.isEmpty { TerminalEmptyState(titleKey: "obs.assessments.empty.title", messageKey: "obs.assessments.empty.message", actionKey: "obs.assessment.new", action: { editor = .assessment(nil) }) } else { List { ForEach(rows) { item in Button { editor = .assessment(item.id) } label: { HStack { VStack(alignment: .leading) { Text(item.title).fontWeight(.semibold); Text("\(courseName(item.universityCourseID)) • \(String(localized: String.LocalizationValue(item.kind.titleKey)))").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted) }; Spacer(); if let earned = item.earnedPoints { Text(String(format: String(localized: "obs.score.format"), earned, item.maximumPoints)).monospacedDigit() } else { Text("obs.ungraded").foregroundStyle(TerminalTokens.warning) }; Text(item.dueDate, style: .date) }.padding(.vertical, 5) }.buttonStyle(.plain).contextMenu { Button("action.edit") { editor = .assessment(item.id) }; Button("action.delete", role: .destructive) { deletion = .assessment(item.id) } } } }.listStyle(.inset).scrollContentBackground(.hidden) } } }

    private var scaleList: some View { Group { if gradeBands.isEmpty { TerminalEmptyState(titleKey: "obs.scale.empty.title", messageKey: "obs.scale.empty.message", actionKey: "obs.scale.new", action: { editor = .band(nil) }) } else { VStack(alignment: .leading) { Text("obs.scale.help").foregroundStyle(TerminalTokens.phosphorMuted).padding(12); List { ForEach(gradeBands.sorted { $0.minimumPercent > $1.minimumPercent }) { band in Button { editor = .band(band.id) } label: { HStack { Text(band.letter).fontWeight(.bold); Spacer(); Text(String(format: "≥ %.1f%%", band.minimumPercent)); Text(String(format: String(localized: "obs.points.format"), band.gradePoints)) }.padding(.vertical, 5) }.buttonStyle(.plain).contextMenu { Button("action.edit") { editor = .band(band.id) }; Button("action.delete", role: .destructive) { deletion = .band(band.id) } } } }.listStyle(.inset).scrollContentBackground(.hidden) } } } }

    private func createNew() { switch viewModel.section { case .assessments: editor = .assessment(nil); case .gradeScale: editor = .band(nil); default: editor = .course(nil) } }
    @ViewBuilder private func editorView(_ value: OBSEditor) -> some View { switch value { case .course(let id): OBSCourseEditor(course: universityCourses.first { $0.id == id }, studyCourses: studyCourses, viewModel: viewModel); case .assessment(let id): OBSAssessmentEditor(assessment: assessments.first { $0.id == id }, courses: universityCourses, defaultCourseID: viewModel.selectedCourseID, viewModel: viewModel); case .band(let id): GradeBandEditor(band: gradeBands.first { $0.id == id }, allBands: gradeBands, viewModel: viewModel) } }
    private func performDelete() { guard let deletion else { return }; do { switch deletion { case .course(let id): if let value = universityCourses.first(where: { $0.id == id }) { try viewModel.deleteCourse(value, assessments: assessments, context: context) }; case .assessment(let id): if let value = assessments.first(where: { $0.id == id }) { try viewModel.delete(value, context: context) }; case .band(let id): if let value = gradeBands.first(where: { $0.id == id }) { try viewModel.delete(value, context: context) } } } catch { viewModel.errorMessage = error.localizedDescription }; self.deletion = nil }
    private func courseName(_ id: UUID) -> String { universityCourses.first(where: { $0.id == id })?.name ?? String(localized: "obs.unknownCourse") }
}

private enum OBSEditor: Identifiable { case course(UUID?), assessment(UUID?), band(UUID?); var id: String { switch self { case .course(let id): "course-\(id?.uuidString ?? "new")"; case .assessment(let id): "assessment-\(id?.uuidString ?? "new")"; case .band(let id): "band-\(id?.uuidString ?? "new")" } } }
private enum OBSDeletion { case course(UUID), assessment(UUID), band(UUID) }
private extension View { func terminalOBSPanel() -> some View { padding(12).frame(maxWidth: .infinity, alignment: .leading).background(TerminalTokens.surface).overlay(RoundedRectangle(cornerRadius: 3).stroke(TerminalTokens.border)) } }
