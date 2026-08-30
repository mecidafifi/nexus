import SwiftUI
import SwiftData

struct OBSCourseEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let course: UniversityCourse?
    let studyCourses: [Course]
    @ObservedObject var viewModel: OBSViewModel
    @State private var name: String; @State private var code: String; @State private var semester: String; @State private var credits: Double; @State private var linkedStudyCourseID: UUID?; @State private var active: Bool; @State private var error: String?
    init(course: UniversityCourse?, studyCourses: [Course], viewModel: OBSViewModel) { self.course = course; self.studyCourses = studyCourses; self.viewModel = viewModel; _name = State(initialValue: course?.name ?? ""); _code = State(initialValue: course?.code ?? ""); _semester = State(initialValue: course?.semester ?? ""); _credits = State(initialValue: course?.creditHours ?? 3); _linkedStudyCourseID = State(initialValue: course?.linkedStudyCourseID); _active = State(initialValue: course?.isActive ?? true) }
    var body: some View { TerminalWindow { TerminalDialog(titleKey: course == nil ? "obs.course.editor.new" : "obs.course.editor.edit") { TerminalForm { TextField("obs.course.name", text: $name); TextField("obs.course.code", text: $code); TextField("obs.course.semester", text: $semester); Stepper(value: $credits, in: 0.5...30, step: 0.5) { LabeledContent("obs.course.credits", value: String(format: "%.1f", credits)) }; Picker("obs.course.studyLink", selection: $linkedStudyCourseID) { Text("obs.course.noStudyLink").tag(UUID?.none); ForEach(studyCourses) { Text($0.name).tag(Optional($0.id)) } }; Toggle("obs.course.active", isOn: $active) }.frame(height: 340); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; actions }.padding() }.frame(width: 560, height: 530).onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() } }
    private var actions: some View { HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }
    private func save() { do { try viewModel.saveCourse(course, name: name, code: code, semester: semester, creditHours: credits, linkedStudyCourseID: linkedStudyCourseID, isActive: active, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}

struct OBSAssessmentEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let assessment: OBSAssessment?
    let courses: [UniversityCourse]
    @ObservedObject var viewModel: OBSViewModel
    @State private var courseID: UUID?; @State private var title: String; @State private var kind: AssessmentKind; @State private var dueDate: Date; @State private var maximum: Double; @State private var isGraded: Bool; @State private var earned: Double; @State private var weight: Double; @State private var note: String; @State private var error: String?
    init(assessment: OBSAssessment?, courses: [UniversityCourse], defaultCourseID: UUID?, viewModel: OBSViewModel) { self.assessment = assessment; self.courses = courses; self.viewModel = viewModel; _courseID = State(initialValue: assessment?.universityCourseID ?? defaultCourseID ?? courses.first?.id); _title = State(initialValue: assessment?.title ?? ""); _kind = State(initialValue: assessment?.kind ?? .midterm); _dueDate = State(initialValue: assessment?.dueDate ?? .now); _maximum = State(initialValue: assessment?.maximumPoints ?? 100); _isGraded = State(initialValue: assessment?.earnedPoints != nil); _earned = State(initialValue: assessment?.earnedPoints ?? 0); _weight = State(initialValue: assessment?.weightPercent ?? 0); _note = State(initialValue: assessment?.note ?? "") }
    var body: some View { TerminalWindow { TerminalDialog(titleKey: assessment == nil ? "obs.assessment.editor.new" : "obs.assessment.editor.edit") { TerminalForm { Picker("obs.assessment.course", selection: $courseID) { Text("obs.selectCourse").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }; TextField("obs.assessment.title", text: $title); Picker("obs.assessment.kind", selection: $kind) { ForEach(AssessmentKind.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }; DatePicker("obs.assessment.date", selection: $dueDate); TextField("obs.assessment.maximum", value: $maximum, format: .number); TextField("obs.assessment.weight", value: $weight, format: .number); Toggle("obs.assessment.graded", isOn: $isGraded); if isGraded { TextField("obs.assessment.earned", value: $earned, format: .number) }; TextField("obs.assessment.note", text: $note, axis: .vertical).lineLimit(2...4) }.frame(height: 470); Text("obs.calculation.help").font(.caption).foregroundStyle(TerminalTokens.phosphorMuted); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; actions }.padding() }.frame(width: 590, height: 680).onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() } }
    private var actions: some View { HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }
    private func save() { do { try viewModel.saveAssessment(assessment, courseID: courseID, title: title, kind: kind, dueDate: dueDate, maximumPoints: maximum, earnedPoints: isGraded ? earned : nil, weightPercent: weight, note: note, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}

struct GradeBandEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let band: GradeScaleBand?
    let allBands: [GradeScaleBand]
    @ObservedObject var viewModel: OBSViewModel
    @State private var letter: String; @State private var minimum: Double; @State private var points: Double; @State private var error: String?
    init(band: GradeScaleBand?, allBands: [GradeScaleBand], viewModel: OBSViewModel) { self.band = band; self.allBands = allBands; self.viewModel = viewModel; _letter = State(initialValue: band?.letter ?? ""); _minimum = State(initialValue: band?.minimumPercent ?? 0); _points = State(initialValue: band?.gradePoints ?? 0) }
    var body: some View { TerminalWindow { TerminalDialog(titleKey: band == nil ? "obs.scale.editor.new" : "obs.scale.editor.edit") { TerminalForm { TextField("obs.scale.letter", text: $letter); TextField("obs.scale.minimum", value: $minimum, format: .number); TextField("obs.scale.points", value: $points, format: .number) }.frame(height: 210); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }.padding() }.frame(width: 490, height: 390).onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in save() } }
    private func save() { do { try viewModel.saveBand(band, letter: letter, minimum: minimum, points: points, existing: allBands, context: context); dismiss() } catch { self.error = error.localizedDescription } }
}
