import SwiftUI
import SwiftData
import AVFoundation

struct LectureListView: View {
    @Query(sort: \Lecture.date, order: .reverse) private var lectures: [Lecture]
    @Query(sort: \Course.name) private var courses: [Course]
    @Query private var recordings: [AudioRecording]
    @Environment(\.modelContext) private var context
    @State private var showingNew = false
    @State private var editing: Lecture?
    @State private var deleting: Lecture?
    @State private var search = ""

    private var filtered: [Lecture] { search.isEmpty ? lectures : lectures.filter { $0.title.localizedCaseInsensitiveContains(search) || courseName($0.courseID).localizedCaseInsensitiveContains(search) } }
    private func courseName(_ id: UUID?) -> String { courses.first { $0.id == id }?.name ?? "Ders atanmamış" }

    var body: some View {
        NavigationStack {
            ZStack {
                TerminalBackground()
                if filtered.isEmpty { TerminalEmptyState(icon: "person.wave.2", title: "Oturum yok", message: courses.isEmpty ? "Önce bir ders ekleyin." : "İlk ders oturumunuzu ekleyin.") }
                else {
                    List(filtered) { lecture in
                        NavigationLink { LectureDetailView(lecture: lecture) } label: {
                            HStack(spacing: 12) {
                                VStack { Text(lecture.date, format: .dateTime.day()).font(.title2.bold()); Text(lecture.date, format: .dateTime.month(.abbreviated)).font(.caption) }
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(lecture.weekNumber). Hafta • \(lecture.lessonNumber). Ders").font(.caption.bold()).foregroundStyle(PadTokens.phosphor)
                                    Text(lecture.title).font(.headline)
                                    Text("\(courseName(lecture.courseID)) • \(lecture.date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(PadTokens.phosphorDim)
                                }
                                Spacer(); TerminalStatusBadge(text: lecture.attendance.title)
                            }.padding(.vertical, 6)
                        }.swipeActions {
                            Button(role: .destructive) { deleting = lecture } label: { Label("Sil", systemImage: "trash") }
                            Button { editing = lecture } label: { Label("Düzenle", systemImage: "pencil") }
                        }
                    }.scrollContentBackground(.hidden)
                }
            }.terminalPage().navigationTitle("Oturumlar")
                .searchable(text: $search, prompt: "Oturum ara")
                .toolbar { Button { showingNew = true } label: { Label("Yeni oturum", systemImage: "plus") }.disabled(courses.isEmpty) }
                .sheet(isPresented: $showingNew) { LectureEditor(courses: courses) }
                .sheet(item: $editing) { LectureEditor(lecture: $0, courses: courses) }
                .alert("Oturum silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
                    Button("Vazgeç", role: .cancel) { deleting = nil }
                    Button("Sil", role: .destructive) { if let deleting { deleteLecture(deleting) }; deleting = nil }
                } message: { Text("Bu oturuma bağlı yerel ses kayıtları da silinir.") }
        }
    }

    private func deleteLecture(_ lecture: Lecture) {
        recordings.filter { $0.lectureID == lecture.id }.forEach { recording in
            try? AudioRecordingService.delete(fileName: recording.storedFileName)
            context.delete(recording)
        }
        context.delete(lecture)
        try? context.save()
    }
}

struct LectureEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allLectures: [Lecture]
    let lecture: Lecture?
    let courses: [Course]
    @State private var courseID: UUID?
    @State private var weekNumber: Int
    @State private var lessonNumber: Int
    @State private var title: String
    @State private var date: Date
    @State private var attendance: LectureAttendance
    @State private var review: LectureReviewStatus
    @State private var note: String
    @State private var error: String?

    init(lecture: Lecture? = nil, courses: [Course], initialCourseID: UUID? = nil, initialWeekNumber: Int = 1, initialLessonNumber: Int = 1) {
        self.lecture = lecture; self.courses = courses
        _courseID = State(initialValue: lecture?.courseID ?? initialCourseID ?? courses.first?.id); _title = State(initialValue: lecture?.title ?? "")
        _weekNumber = State(initialValue: lecture?.weekNumber ?? initialWeekNumber); _lessonNumber = State(initialValue: lecture?.lessonNumber ?? initialLessonNumber)
        _date = State(initialValue: lecture?.date ?? .now); _attendance = State(initialValue: lecture?.attendance ?? .unmarked)
        _review = State(initialValue: lecture?.reviewStatus ?? .notReviewed); _note = State(initialValue: lecture?.note ?? "")
    }
    private var selectedCourse: Course? { courses.first { $0.id == courseID } }
    private var maximumWeek: Int { max(selectedCourse?.semesterWeekCount ?? 15, 1) }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Ders", selection: $courseID) { Text("Seçin").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                    .onChange(of: courseID) { _, _ in weekNumber = min(weekNumber, maximumWeek) }
                Section("Dönem konumu") {
                    Stepper("Hafta: \(weekNumber)", value: $weekNumber, in: 1...maximumWeek)
                    Stepper("Ders: \(lessonNumber)", value: $lessonNumber, in: 1...10)
                    Text("Aynı haftadaki birinci ve ikinci dersi ayrı ayrı açabilir, her birine kendi ses kaydını ve ders defterini ekleyebilirsiniz.")
                        .font(.caption).foregroundStyle(PadTokens.phosphorDim)
                }
                TextField("Oturum başlığı", text: $title)
                DatePicker("Tarih ve saat", selection: $date)
                Picker("Katılım", selection: $attendance) { ForEach(LectureAttendance.allCases) { Text($0.title).tag($0) } }
                Picker("İnceleme", selection: $review) { ForEach(LectureReviewStatus.allCases) { Text($0.title).tag($0) } }
                TextField("Ders defteri başlangıç notu (isteğe bağlı)", text: $note, axis: .vertical).lineLimit(3...8)
                if let error { TerminalErrorState(message: error) }
            }.navigationTitle(lecture == nil ? "Yeni oturum" : "Oturumu düzenle")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } } }
        }.tint(PadTokens.phosphor)
    }
    private func save() {
        if let message = Lecture.validationError(title: title, courseID: courseID, weekNumber: weekNumber, lessonNumber: lessonNumber, semesterWeekCount: maximumWeek) { error = message; return }
        if CourseNotebookPolicy.hasDuplicate(courseID: courseID, week: weekNumber, lesson: lessonNumber, excluding: lecture?.id, in: allLectures) {
            error = "Bu dersin \(weekNumber). haftasında \(lessonNumber). ders zaten var. Mevcut dersi açın veya farklı bir ders numarası seçin."
            return
        }
        if let lecture { lecture.courseID = courseID; lecture.weekNumber = weekNumber; lecture.lessonNumber = lessonNumber; lecture.title = title.trimmingCharacters(in: .whitespacesAndNewlines); lecture.date = date; lecture.attendance = attendance; lecture.reviewStatus = review; lecture.note = note; lecture.updatedAt = .now }
        else { context.insert(Lecture(courseID: courseID, title: title, date: date, attendance: attendance, reviewStatus: review, note: note, weekNumber: weekNumber, lessonNumber: lessonNumber)) }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
}

struct LectureDetailView: View {
    @Bindable var lecture: Lecture
    @Query private var courses: [Course]
    @Query(sort: \AudioRecording.createdAt, order: .reverse) private var recordings: [AudioRecording]
    @Environment(\.modelContext) private var context
    @StateObject private var audio = AudioRecordingService()
    @StateObject private var playback = AudioPlaybackService()
    @State private var showPermissionExplanation = false
    @State private var error: String?
    @State private var pendingFileName: String?
    @State private var deletingRecording: AudioRecording?
    @State private var notebookDraft: String
    @State private var notebookSaveStatus = "Kaydedildi"
    @State private var notebookSaveTask: Task<Void, Never>?

    init(lecture: Lecture) {
        self.lecture = lecture
        _notebookDraft = State(initialValue: lecture.note)
    }

    private var courseName: String { courses.first { $0.id == lecture.courseID }?.name ?? "Ders atanmamış" }
    private var lectureRecordings: [AudioRecording] { recordings.filter { $0.lectureID == lecture.id } }

    var body: some View {
        ZStack {
            TerminalBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TerminalCard("Oturum") {
                        Text("\(lecture.weekNumber). Hafta • \(lecture.lessonNumber). Ders").font(.headline).foregroundStyle(PadTokens.phosphor)
                        Text(lecture.title).font(.title2.bold())
                        Text(courseName)
                        Text(lecture.date.formatted(date: .complete, time: .shortened)).foregroundStyle(PadTokens.phosphorDim)
                    }
                    TerminalCard("Durum") {
                        Picker("Katılım", selection: Binding(get: { lecture.attendance }, set: { lecture.attendance = $0; try? context.save() })) { ForEach(LectureAttendance.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                        Picker("İnceleme", selection: Binding(get: { lecture.reviewStatus }, set: { lecture.reviewStatus = $0; try? context.save() })) { ForEach(LectureReviewStatus.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                    }
                    TerminalCard("Yerel ses kayıtları") {
                        Text("Mikrofon yalnız siz kayıt düğmesine bastıktan ve açıklamayı onayladıktan sonra kullanılır. Kayıtlar cihazdaki uygulama alanında kalır.").font(.caption).foregroundStyle(PadTokens.phosphorDim)
                        if audio.isRecording {
                            HStack {
                                Image(systemName: audio.isPaused ? "pause.circle" : "waveform"); Text(audio.elapsed.formattedDuration)
                                Spacer()
                                Button(audio.isPaused ? "Sürdür" : "Duraklat") { audio.isPaused ? audio.resume() : audio.pause() }.buttonStyle(.bordered)
                                Button("Kaydı bitir") { stopRecording() }.buttonStyle(.borderedProminent)
                            }
                        } else { Button { showPermissionExplanation = true } label: { Label("Ses kaydı başlat", systemImage: "mic") }.buttonStyle(.bordered) }
                        ForEach(lectureRecordings) { recording in
                            HStack {
                                Button { do { try playback.toggle(fileName: recording.storedFileName) } catch { self.error = error.localizedDescription } } label: { Image(systemName: playback.playingFileName == recording.storedFileName ? "stop.fill" : "play.fill").frame(width: 44, height: 44) }.buttonStyle(.bordered).accessibilityLabel("\(recording.title) \(playback.playingFileName == recording.storedFileName ? "durdur" : "oynat")")
                                VStack(alignment: .leading) { Text(recording.title); Text("\(recording.durationSeconds.formattedDuration) • \(fileSize(recording))").font(.caption) }
                                Spacer(); Button(role: .destructive) { deletingRecording = recording } label: { Image(systemName: "trash").frame(width: 44, height: 44) }.accessibilityLabel("\(recording.title) kaydını sil")
                            }
                        }
                        Text("Toplam yerel ses alanı: \(totalAudioSize). Kayıt silme geri alınamaz; yalnız seçilen dosya ve metadatası kaldırılır.").font(.caption).foregroundStyle(PadTokens.phosphorDim)
                    }
                    TerminalCard("Ders defteri") {
                        Text("Bu alana öğretim elemanının anlattıklarını, örnekleri ve sınav notlarını yazın. Metin yalnız bu hafta ve ders oturumuna bağlı olarak cihazda saklanır.")
                            .font(.caption).foregroundStyle(PadTokens.phosphorDim)
                        TextEditor(text: $notebookDraft)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 360)
                            .background(PadTokens.panel.opacity(0.72))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(PadTokens.phosphorDim.opacity(0.7)))
                            .accessibilityLabel("\(lecture.weekNumber). hafta \(lecture.lessonNumber). ders defteri")
                            .accessibilityHint("Uzun ders notunuzu yazın. Değişiklikler otomatik kaydedilir.")
                            .onChange(of: notebookDraft) { _, _ in scheduleNotebookSave() }
                        HStack {
                            Label(notebookSaveStatus, systemImage: notebookDraft == lecture.note ? "checkmark.circle" : "arrow.triangle.2.circlepath")
                                .font(.caption).foregroundStyle(PadTokens.phosphorDim)
                            Spacer()
                            Button("Şimdi kaydet") { persistNotebook() }
                                .buttonStyle(.bordered)
                                .frame(minHeight: PadTokens.minimumTap)
                        }
                    }
                    if let error { TerminalErrorState(message: error) }
                }.padding(24)
            }
        }.terminalPage().navigationTitle("Oturum ayrıntısı")
            .alert("Mikrofon izni", isPresented: $showPermissionExplanation) {
                Button("Vazgeç", role: .cancel) { }
                Button("İzin ver ve başlat") { Task { await requestAndStart() } }
            } message: { Text("Ses yalnız bu oturum için, siz durdurana kadar kaydedilir. Dosya uygulamanın yerel alanında saklanır; ağ veya bulut kullanılmaz.") }
            .alert("Ses kaydı silinsin mi?", isPresented: Binding(get: { deletingRecording != nil }, set: { if !$0 { deletingRecording = nil } })) {
                Button("Vazgeç", role: .cancel) { deletingRecording = nil }
                Button("Sil", role: .destructive) { if let deletingRecording { delete(deletingRecording) }; deletingRecording = nil }
            } message: { Text("Yerel ses dosyası kalıcı olarak silinir.") }
            .onDisappear {
                notebookSaveTask?.cancel()
                if notebookDraft != lecture.note { persistNotebook() }
                if audio.isRecording { audio.cancel() }
                playback.stop()
            }
    }
    private func requestAndStart() async {
        guard await audio.requestPermission() else { error = AudioServiceError.permissionDenied.localizedDescription; return }
        do { pendingFileName = try audio.start() } catch { self.error = error.localizedDescription }
    }
    private func stopRecording() {
        do {
            let result = try audio.stop(); let recording = AudioRecording(lectureID: lecture.id, title: "\(lecture.weekNumber). Hafta • \(lecture.lessonNumber). Ders — Ses", storedFileName: result.fileName, durationSeconds: result.duration)
            context.insert(recording); try context.save(); pendingFileName = nil
        } catch { self.error = error.localizedDescription }
    }
    private func scheduleNotebookSave() {
        notebookSaveTask?.cancel()
        guard notebookDraft != lecture.note else { notebookSaveStatus = "Kaydedildi"; return }
        notebookSaveStatus = "Kaydediliyor…"
        notebookSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            persistNotebook()
        }
    }
    private func persistNotebook() {
        notebookSaveTask?.cancel()
        guard NoteContentPolicy.isValid(body: notebookDraft) else {
            notebookSaveStatus = "Kaydedilemedi"
            error = "Ders defteri 1 MB yerel güvenlik sınırını aşıyor."
            return
        }
        guard notebookDraft != lecture.note else { notebookSaveStatus = "Kaydedildi"; return }
        lecture.note = notebookDraft
        lecture.updatedAt = .now
        do {
            try context.save()
            notebookSaveStatus = "Kaydedildi"
        } catch {
            notebookSaveStatus = "Kaydedilemedi"
            self.error = error.localizedDescription
        }
    }
    private func delete(_ recording: AudioRecording) { try? AudioRecordingService.delete(fileName: recording.storedFileName); context.delete(recording); try? context.save() }
    private func fileSize(_ recording: AudioRecording) -> String {
        ByteCountFormatter.string(fromByteCount: fileBytes(recording), countStyle: .file)
    }
    private var totalAudioSize: String {
        let total = lectureRecordings.reduce(Int64(0)) { $0 + fileBytes($1) }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
    private func fileBytes(_ recording: AudioRecording) -> Int64 {
        guard let url = try? AudioRecordingService.url(for: recording.storedFileName),
              let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let number = attributes[.size] as? NSNumber else { return 0 }
        return number.int64Value
    }
}

private extension TimeInterval {
    var formattedDuration: String { String(format: "%02d:%02d", Int(self) / 60, Int(self) % 60) }
}
