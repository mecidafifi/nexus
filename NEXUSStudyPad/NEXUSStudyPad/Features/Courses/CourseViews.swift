import SwiftUI
import SwiftData

struct CourseListView: View {
    @Query(sort: \Course.name) private var courses: [Course]
    @Environment(\.modelContext) private var context
    @State private var editing: Course?
    @State private var showingNew = false
    @State private var deleting: Course?
    @State private var search = ""

    private var filtered: [Course] { search.isEmpty ? courses : courses.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.code.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationStack {
            ZStack {
                TerminalBackground()
                Group {
                    if filtered.isEmpty { TerminalEmptyState(icon: "books.vertical", title: "Ders yok", message: search.isEmpty ? "İlk dersinizi ekleyin." : "Aramayla eşleşen ders bulunamadı.") }
                    else {
                        List(filtered) { course in
                            NavigationLink { CourseDetailView(course: course) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(course.name).font(.headline)
                                    if !course.code.isEmpty || !course.instructor.isEmpty {
                                        Text([course.code, course.instructor].filter { !$0.isEmpty }.joined(separator: " • ")).font(.caption).foregroundStyle(PadTokens.phosphorDim)
                                    }
                                }.padding(.vertical, 7)
                            }
                            .swipeActions {
                                Button(role: .destructive) { deleting = course } label: { Label("Sil", systemImage: "trash") }
                                Button { editing = course } label: { Label("Düzenle", systemImage: "pencil") }
                            }
                        }.scrollContentBackground(.hidden)
                    }
                }
            }
            .terminalPage().navigationTitle("Dersler")
            .searchable(text: $search, prompt: "Ders veya kod ara")
            .toolbar { Button { showingNew = true } label: { Label("Yeni ders", systemImage: "plus") }.accessibilityHint("Yeni ders formunu açar") }
            .sheet(isPresented: $showingNew) { CourseEditor() }
            .sheet(item: $editing) { CourseEditor(course: $0) }
            .alert("Ders silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                Button("Vazgeç", role: .cancel) { deleting = nil }
                Button("Sil", role: .destructive) { if let deleting { delete(deleting) }; deleting = nil }
            } message: { Text("Bağlı oturum, PDF, not ve görevler korunup ders bağlantıları kaldırılır. Bu derse ait haftalık program kuralları silinir.") }
        }
    }

    private func delete(_ course: Course) { try? CourseDeletionService.delete(course, context: context) }
}

struct CourseEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let course: Course?
    @State private var name: String
    @State private var code: String
    @State private var instructor: String
    @State private var semesterWeekCount: Int
    @State private var error: String?

    init(course: Course? = nil) {
        self.course = course
        _name = State(initialValue: course?.name ?? ""); _code = State(initialValue: course?.code ?? ""); _instructor = State(initialValue: course?.instructor ?? "")
        _semesterWeekCount = State(initialValue: course?.semesterWeekCount ?? 15)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Ders bilgileri") {
                    TextField("Ders adı", text: $name)
                    TextField("Ders kodu (isteğe bağlı)", text: $code)
                    TextField("Öğretim elemanı (isteğe bağlı)", text: $instructor)
                    Stepper("Dönem haftası: \(semesterWeekCount)", value: $semesterWeekCount, in: 1...30)
                }
                if let error { TerminalErrorState(message: error) }
            }.navigationTitle(course == nil ? "Yeni ders" : "Dersi düzenle")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.fontWeight(.bold) }
                }
        }.presentationDetents([.medium, .large]).tint(PadTokens.phosphor)
    }
    private func save() {
        if let message = Course.validationError(name: name) { error = message; return }
        if let course { course.name = name.trimmingCharacters(in: .whitespacesAndNewlines); course.code = code.trimmingCharacters(in: .whitespacesAndNewlines); course.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines); course.semesterWeekCount = semesterWeekCount; course.updatedAt = .now }
        else { context.insert(Course(name: name, code: code, instructor: instructor, semesterWeekCount: semesterWeekCount)) }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
}

private enum CourseNotebookTab: String, CaseIterable, Identifiable {
    case overview = "Özet", lectures = "Haftalar", pdfs = "PDF", notes = "Notlar", tasks = "Görevler", audio = "Ses"
    var id: String { rawValue }
}

struct CourseDetailView: View {
    let course: Course
    @Query private var lectures: [Lecture]
    @Query private var documents: [StudyDocument]
    @Query private var notes: [StudyNote]
    @Query private var tasks: [StudyTask]
    @Query private var recordings: [AudioRecording]
    @Query(sort: \CourseScheduleRule.weekday) private var scheduleRules: [CourseScheduleRule]
    @Query(sort: \Course.name) private var courses: [Course]
    @Environment(\.modelContext) private var context
    @State private var tab: CourseNotebookTab = .overview
    @State private var newLecture = false
    @State private var newLectureWeek = 1
    @State private var newLectureNumber = 1
    @State private var expandedWeeks: Set<Int> = [1]
    @State private var newNote = false
    @State private var newTask = false
    @State private var editingNote: StudyNote?
    @State private var newSchedule = false
    @State private var editingSchedule: CourseScheduleRule?
    @State private var deletingSchedule: CourseScheduleRule?

    private var courseLectures: [Lecture] { lectures.filter { $0.courseID == course.id }.sorted { $0.date > $1.date } }
    private var courseDocuments: [StudyDocument] { documents.filter { $0.courseID == course.id }.sorted { $0.importedAt > $1.importedAt } }
    private var courseNotes: [StudyNote] { notes.filter { $0.courseID == course.id }.sorted { $0.updatedAt > $1.updatedAt } }
    private var courseTasks: [StudyTask] { tasks.filter { $0.courseID == course.id }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) } }
    private var courseSchedules: [CourseScheduleRule] {
        scheduleRules.filter { $0.courseID == course.id }.sorted {
            if $0.weekday != $1.weekday { return $0.weekday < $1.weekday }
            return $0.startMinutes < $1.startMinutes
        }
    }
    private var courseRecordings: [AudioRecording] { let ids = Set(courseLectures.map(\.id)); return recordings.filter { ids.contains($0.lectureID) }.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        ZStack {
            TerminalBackground()
            VStack(spacing: 12) {
                Picker("Ders defteri bölümü", selection: $tab) { ForEach(CourseNotebookTab.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).padding(.horizontal, 20).accessibilityHint("Ders defteri bölümünü değiştirir")
                ScrollView { VStack(alignment: .leading, spacing: 14) { tabContent }.padding(20) }
            }
        }.terminalPage().navigationTitle(course.name)
            .toolbar {
                if tab == .lectures { Button { prepareNewLecture() } label: { Label("Yeni ders oturumu", systemImage: "plus") } }
                if tab == .notes { Button { newNote = true } label: { Label("Yeni not", systemImage: "plus") } }
                if tab == .tasks { Button { newTask = true } label: { Label("Yeni görev", systemImage: "plus") } }
            }
            .sheet(isPresented: $newLecture) { LectureEditor(courses: courses, initialCourseID: course.id, initialWeekNumber: newLectureWeek, initialLessonNumber: newLectureNumber) }
            .sheet(isPresented: $newNote) { NoteEditor(courses: courses, lectures: lectures, initialCourseID: course.id) }
            .sheet(isPresented: $newTask) { TaskEditor(courses: courses, initialCourseID: course.id) }
            .sheet(item: $editingNote) { NoteEditor(note: $0, courses: courses, lectures: lectures) }
            .sheet(isPresented: $newSchedule) { ScheduleRuleEditor(courseID: course.id, existingRules: scheduleRules) }
            .sheet(item: $editingSchedule) { ScheduleRuleEditor(courseID: course.id, rule: $0, existingRules: scheduleRules) }
            .alert("Program kuralı silinsin mi?", isPresented: Binding(get: { deletingSchedule != nil }, set: { if !$0 { deletingSchedule = nil } })) {
                Button("Vazgeç", role: .cancel) { deletingSchedule = nil }
                Button("Sil", role: .destructive) {
                    if let deletingSchedule { context.delete(deletingSchedule); try? context.save() }
                    deletingSchedule = nil
                }
            } message: { Text("Yalnız seçili haftalık program kuralı silinir; ders ve geçmiş oturumlar korunur.") }
    }

    @ViewBuilder private var tabContent: some View {
        switch tab {
        case .overview:
            TerminalCard("Ders") { Text(course.name).font(.title2.bold()); if !course.code.isEmpty { Text(course.code) }; if !course.instructor.isEmpty { Text(course.instructor).foregroundStyle(PadTokens.phosphorDim) } }
            TerminalCard("Defter durumu") { HStack { metric("Oturum", courseLectures.count); metric("PDF", courseDocuments.count); metric("Not", courseNotes.count); metric("Açık", courseTasks.filter { !$0.isCompleted }.count) } }
            TerminalCard("Haftalık program") {
                HStack {
                    Text("Tekrarlanan ders saatleri").font(.headline)
                    Spacer()
                    Button { newSchedule = true } label: { Label("Program ekle", systemImage: "calendar.badge.plus") }
                        .buttonStyle(.bordered)
                        .frame(minHeight: PadTokens.minimumTap)
                        .accessibilityHint("Bu ders için haftalık program kuralı oluşturur")
                }
                if courseSchedules.isEmpty { Text("Program kuralı yok.").foregroundStyle(PadTokens.phosphorDim) }
                ForEach(courseSchedules) { rule in
                    HStack(spacing: 10) {
                        Button { editingSchedule = rule } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(weekday(rule.weekday)) • \(clock(rule.startMinutes))–\(clock(rule.startMinutes + rule.durationMinutes))")
                                    .fontWeight(.semibold)
                                HStack {
                                    if !rule.location.isEmpty { Text(rule.location) }
                                    Text(rule.isActive ? "Aktif" : "Devre dışı")
                                }
                                .font(.caption)
                                .foregroundStyle(PadTokens.phosphorDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: PadTokens.minimumTap)
                        .accessibilityLabel("\(weekday(rule.weekday)), \(clock(rule.startMinutes)) ile \(clock(rule.startMinutes + rule.durationMinutes)), \(rule.isActive ? "aktif" : "devre dışı")")
                        .accessibilityHint("Program kuralını düzenler")
                        Button(role: .destructive) { deletingSchedule = rule } label: { Image(systemName: "trash") }
                            .buttonStyle(.bordered)
                            .frame(minWidth: PadTokens.minimumTap, minHeight: PadTokens.minimumTap)
                            .accessibilityLabel("Program kuralını sil")
                    }
                }
            }
        case .lectures:
            TerminalCard("Dönem defteri") {
                Text("Bu ders \(course.semesterWeekCount) haftaya ayrıldı. Her hafta yalnız gerçekten aldığınız ders oturumlarını ekleyin; ses ve ders defteri o oturumda birlikte kalır.")
                    .foregroundStyle(PadTokens.phosphorDim)
            }
            ForEach(1...max(course.semesterWeekCount, 1), id: \.self) { week in weekNotebook(week) }
        case .pdfs:
            if courseDocuments.isEmpty { TerminalEmptyState(icon: "doc.richtext", title: "PDF yok", message: "Belgeler bölümünden PDF seçip bu derse bağlayın.") }
            ForEach(courseDocuments) { document in NavigationLink { DocumentViewerView(document: document) } label: { TerminalCard("PDF") { Label(document.title, systemImage: "doc.richtext") } }.buttonStyle(.plain) }
        case .notes:
            if courseNotes.isEmpty { TerminalEmptyState(icon: "note.text", title: "Not yok", message: "Metin veya el yazısı notu ekleyin.") }
            ForEach(courseNotes) { note in Button { editingNote = note } label: { TerminalCard(note.kind.title) { Text(note.title).font(.headline); if note.kind == .markdown { Text(note.body).lineLimit(3).foregroundStyle(PadTokens.phosphorDim) } } }.buttonStyle(.plain).accessibilityHint("Notu açar") }
        case .tasks:
            if courseTasks.isEmpty { TerminalEmptyState(icon: "checklist", title: "Görev yok", message: "Bu derse bağlı görev ekleyin.") }
            ForEach(courseTasks) { task in Button { task.isCompleted.toggle(); task.updatedAt = .now; try? context.save() } label: { TerminalCard(task.isCompleted ? "Tamamlandı" : "Açık") { Label(task.title, systemImage: task.isCompleted ? "checkmark.square.fill" : "square"); if let due = task.dueDate { Text(due.formatted(date: .abbreviated, time: .shortened)).font(.caption) } } }.buttonStyle(.plain).accessibilityHint("Görev durumunu değiştirir") }
        case .audio:
            if courseRecordings.isEmpty { TerminalEmptyState(icon: "waveform", title: "Ses kaydı yok", message: "Bir oturumu açıp açık kayıt düğmesini kullanın.") }
            ForEach(courseRecordings) { recording in TerminalCard("Yerel ses") { Text(recording.title).font(.headline); Text(String(format: "%02d:%02d", Int(recording.durationSeconds) / 60, Int(recording.durationSeconds) % 60)).foregroundStyle(PadTokens.phosphorDim) } }
        }
    }
    private func metric(_ title: String, _ value: Int) -> some View { VStack { Text("\(value)").font(.title2.bold()); Text(title).font(.caption) }.frame(maxWidth: .infinity) }
    private func lectures(in week: Int) -> [Lecture] {
        CourseNotebookPolicy.lectures(for: course.id, week: week, from: courseLectures)
    }
    private func nextLessonNumber(in week: Int) -> Int { CourseNotebookPolicy.nextLessonNumber(for: course.id, week: week, from: courseLectures) }
    private func prepareNewLecture(week: Int? = nil, lesson: Int? = nil) {
        let suggestedWeek = week ?? min(max(courseLectures.map(\.weekNumber).max() ?? 1, 1), course.semesterWeekCount)
        newLectureWeek = suggestedWeek
        newLectureNumber = lesson ?? nextLessonNumber(in: suggestedWeek)
        expandedWeeks.insert(suggestedWeek)
        newLecture = true
    }
    private func weekExpandedBinding(_ week: Int) -> Binding<Bool> {
        Binding(get: { expandedWeeks.contains(week) }, set: { value in if value { expandedWeeks.insert(week) } else { expandedWeeks.remove(week) } })
    }
    private func recordingCount(for lecture: Lecture) -> Int { recordings.filter { $0.lectureID == lecture.id }.count }

    private func weekNotebook(_ week: Int) -> some View {
        let weekLectures = lectures(in: week)
        return TerminalCard("\(week). Hafta") {
            DisclosureGroup(isExpanded: weekExpandedBinding(week)) {
                VStack(alignment: .leading, spacing: 10) {
                    if weekLectures.isEmpty {
                        Text("Bu hafta için henüz ders kaydı yok.").foregroundStyle(PadTokens.phosphorDim)
                        HStack {
                            Button { prepareNewLecture(week: week, lesson: 1) } label: { Label("1. dersi ekle", systemImage: "1.circle") }.buttonStyle(.bordered)
                            Button { prepareNewLecture(week: week, lesson: 2) } label: { Label("2. dersi ekle", systemImage: "2.circle") }.buttonStyle(.bordered)
                        }
                    } else {
                        ForEach(weekLectures) { lecture in
                            NavigationLink { LectureDetailView(lecture: lecture) } label: {
                                HStack(spacing: 12) {
                                    Text("\(lecture.lessonNumber)").font(.title2.bold()).frame(width: 38, height: 38).overlay(Circle().stroke(PadTokens.phosphorDim))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(lecture.lessonNumber). Ders • \(lecture.title)").font(.headline)
                                        Text(lecture.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(PadTokens.phosphorDim)
                                    }
                                    Spacer()
                                    if !lecture.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Label("Not", systemImage: "note.text").labelStyle(.iconOnly).accessibilityLabel("Ders defteri dolu") }
                                    let audioCount = recordingCount(for: lecture)
                                    if audioCount > 0 { Label("\(audioCount)", systemImage: "waveform").accessibilityLabel("\(audioCount) ses kaydı") }
                                    TerminalStatusBadge(text: lecture.reviewStatus.title)
                                }
                                .padding(.vertical, 5)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Ses kaydını ve ders defterini açar")
                        }
                        Button { prepareNewLecture(week: week) } label: { Label("Bu haftaya ders ekle", systemImage: "plus.circle") }.buttonStyle(.bordered)
                    }
                }
                .padding(.top, 10)
            } label: {
                HStack {
                    Text("\(weekLectures.count) ders")
                    Spacer()
                    Text(weekLectures.isEmpty ? "Boş" : "\(weekLectures.filter { !$0.note.isEmpty }.count) defter • \(weekLectures.reduce(0) { $0 + recordingCount(for: $1) }) ses")
                        .font(.caption).foregroundStyle(PadTokens.phosphorDim)
                }
            }
        }
    }
    private func weekday(_ value: Int) -> String { let symbols = Calendar.current.weekdaySymbols; return (1...7).contains(value) ? symbols[value - 1] : "?" }
    private func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", (minutes / 60) % 24, minutes % 60) }
}

private struct ScheduleRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let courseID: UUID
    let rule: CourseScheduleRule?
    let existingRules: [CourseScheduleRule]
    @State private var weekday: Int
    @State private var startTime: Date
    @State private var durationMinutes: Int
    @State private var effectiveStart: Date
    @State private var hasEnd: Bool
    @State private var effectiveEnd: Date
    @State private var location: String
    @State private var isActive: Bool
    @State private var error: String?

    init(courseID: UUID, rule: CourseScheduleRule? = nil, existingRules: [CourseScheduleRule]) {
        self.courseID = courseID
        self.rule = rule
        self.existingRules = existingRules
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let initialMinutes = rule?.startMinutes ?? 9 * 60
        _weekday = State(initialValue: rule?.weekday ?? calendar.component(.weekday, from: .now))
        _startTime = State(initialValue: calendar.date(byAdding: .minute, value: initialMinutes, to: today) ?? .now)
        _durationMinutes = State(initialValue: rule?.durationMinutes ?? 50)
        _effectiveStart = State(initialValue: rule?.effectiveStart ?? today)
        _hasEnd = State(initialValue: rule?.effectiveEnd != nil)
        _effectiveEnd = State(initialValue: rule?.effectiveEnd ?? today)
        _location = State(initialValue: rule?.location ?? "")
        _isActive = State(initialValue: rule?.isActive ?? true)
    }

    private var startMinutes: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private var overlappingRules: [CourseScheduleRule] {
        guard isActive else { return [] }
        let newEnd = startMinutes + durationMinutes
        let proposedStartDate = Calendar.current.startOfDay(for: effectiveStart)
        let proposedEndDate = hasEnd ? Calendar.current.startOfDay(for: effectiveEnd) : Date.distantFuture
        return existingRules.filter { candidate in
            candidate.id != rule?.id && candidate.isActive && candidate.weekday == weekday
                && Calendar.current.startOfDay(for: candidate.effectiveStart) <= proposedEndDate
                && (candidate.effectiveEnd.map { Calendar.current.startOfDay(for: $0) } ?? .distantFuture) >= proposedStartDate
                && startMinutes < candidate.startMinutes + candidate.durationMinutes
                && candidate.startMinutes < newEnd
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Haftalık tekrar") {
                    Picker("Gün", selection: $weekday) {
                        ForEach(WeekdayOption.allCases) { option in Text(option.title).tag(option.rawValue) }
                    }
                    DatePicker("Başlangıç saati", selection: $startTime, displayedComponents: .hourAndMinute)
                    Stepper("Süre: \(durationMinutes) dakika", value: $durationMinutes, in: 10...720, step: 5)
                    Toggle("Aktif", isOn: $isActive)
                }
                Section("Geçerlilik") {
                    DatePicker("Başlangıç tarihi", selection: $effectiveStart, displayedComponents: .date)
                    Toggle("Bitiş tarihi ekle", isOn: $hasEnd)
                    if hasEnd { DatePicker("Bitiş tarihi", selection: $effectiveEnd, in: effectiveStart..., displayedComponents: .date) }
                }
                Section("Yer") { TextField("Sınıf veya konum (isteğe bağlı)", text: $location) }
                if !overlappingRules.isEmpty {
                    Section("Çakışma uyarısı") {
                        Label("Aynı gün ve saatte \(overlappingRules.count) başka program kuralı var. Kaydetmeden önce saatleri kontrol edin.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Çakışma uyarısı. Aynı gün ve saatte \(overlappingRules.count) başka program kuralı var.")
                    }
                }
                if let error { TerminalErrorState(message: error) }
            }
            .navigationTitle(rule == nil ? "Program ekle" : "Programı düzenle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() }.fontWeight(.bold) }
            }
        }
        .tint(PadTokens.phosphor)
    }

    private func save() {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: effectiveStart)
        let endDay = hasEnd ? calendar.startOfDay(for: effectiveEnd) : nil
        guard CourseScheduleRule.isValid(
            weekday: weekday,
            startMinutes: startMinutes,
            durationMinutes: durationMinutes,
            effectiveStart: startDay,
            effectiveEnd: endDay
        ) else {
            error = String(localized: "Program günü, saati veya tarih aralığı geçersiz.")
            return
        }
        if let rule {
            rule.weekday = weekday
            rule.startMinutes = startMinutes
            rule.durationMinutes = durationMinutes
            rule.effectiveStart = startDay
            rule.effectiveEnd = endDay
            rule.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
            rule.isActive = isActive
            rule.updatedAt = .now
        } else {
            context.insert(
                CourseScheduleRule(
                    courseID: courseID,
                    weekday: weekday,
                    startMinutes: startMinutes,
                    durationMinutes: durationMinutes,
                    effectiveStart: startDay,
                    effectiveEnd: endDay,
                    location: location,
                    isActive: isActive
                )
            )
        }
        do { try context.save(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

private enum WeekdayOption: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .monday: String(localized: "Pazartesi")
        case .tuesday: String(localized: "Salı")
        case .wednesday: String(localized: "Çarşamba")
        case .thursday: String(localized: "Perşembe")
        case .friday: String(localized: "Cuma")
        case .saturday: String(localized: "Cumartesi")
        case .sunday: String(localized: "Pazar")
        }
    }
}
