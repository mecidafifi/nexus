import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \StudyNote.updatedAt, order: .reverse) private var notes: [StudyNote]
    @Query(sort: \Course.name) private var courses: [Course]
    @Query(sort: \Lecture.date, order: .reverse) private var lectures: [Lecture]
    @Environment(\.modelContext) private var context
    @State private var showingNew = false
    @State private var editing: StudyNote?
    @State private var deleting: StudyNote?
    @State private var search = ""
    private var filtered: [StudyNote] {
        let result = search.isEmpty ? notes : notes.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) }
        return result.sorted { if $0.isPinned != $1.isPinned { return $0.isPinned }; return $0.updatedAt > $1.updatedAt }
    }
    var body: some View {
        NavigationStack {
            ZStack {
                TerminalBackground()
                if filtered.isEmpty { TerminalEmptyState(icon: "note.text", title: "Not yok", message: search.isEmpty ? "Metin veya Apple Pencil notu oluşturun." : "Aramayla eşleşen not yok.") }
                else {
                    List(filtered) { note in
                        Button { editing = note } label: {
                            HStack { Image(systemName: note.kind == .handwritten ? "pencil.and.scribble" : "note.text"); VStack(alignment: .leading, spacing: 5) { HStack { Text(note.title).font(.headline); if note.isPinned { Image(systemName: "pin.fill").accessibilityLabel("Sabitlendi") } }; Text(note.kind.title + " • " + note.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(PadTokens.phosphorDim) }; Spacer() }.padding(.vertical, 6).contentShape(Rectangle())
                        }.buttonStyle(.plain).swipeActions { Button(role: .destructive) { deleting = note } label: { Label("Sil", systemImage: "trash") } }
                    }.scrollContentBackground(.hidden)
                }
            }.terminalPage().navigationTitle("Notlar").searchable(text: $search, prompt: "Başlık veya içerik ara")
                .toolbar { Button { showingNew = true } label: { Label("Yeni not", systemImage: "plus") } }
                .sheet(isPresented: $showingNew) { NoteEditor(courses: courses, lectures: lectures) }
                .sheet(item: $editing) { NoteEditor(note: $0, courses: courses, lectures: lectures) }
                .alert("Not silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) { Button("Vazgeç", role: .cancel) { deleting = nil }; Button("Sil", role: .destructive) { if let deleting { context.delete(deleting); try? context.save() }; deleting = nil } } message: { Text("Bu işlem geri alınamaz.") }
        }
    }
}

struct NoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let note: StudyNote?
    let courses: [Course]
    let lectures: [Lecture]
    @State private var title: String
    @State private var bodyText: String
    @State private var kind: StudyNoteKind
    @State private var drawingData: Data
    @State private var courseID: UUID?
    @State private var lectureID: UUID?
    @State private var pinned: Bool
    @State private var error: String?
    @State private var saveStatus = "Kaydedilmemiş değişiklik yok"
    @State private var autosaveTask: Task<Void, Never>?

    init(note: StudyNote? = nil, courses: [Course], lectures: [Lecture], initialCourseID: UUID? = nil) {
        self.note = note; self.courses = courses; self.lectures = lectures
        _title = State(initialValue: note?.title ?? ""); _bodyText = State(initialValue: note?.body ?? ""); _kind = State(initialValue: note?.kind ?? .markdown)
        _drawingData = State(initialValue: note?.drawingData ?? Data()); _courseID = State(initialValue: note?.courseID ?? initialCourseID); _lectureID = State(initialValue: note?.lectureID); _pinned = State(initialValue: note?.isPinned ?? false)
    }
    private var eligibleLectures: [Lecture] { guard let courseID else { return lectures }; return lectures.filter { $0.courseID == courseID } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    Section("Not defteri") {
                        TextField("Başlık", text: $title)
                        Picker("Tür", selection: $kind) { ForEach(StudyNoteKind.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                        Toggle("Sabitle", isOn: $pinned)
                    }
                    Section("Bağlantı") {
                        Picker("Ders", selection: $courseID) { Text("Atanmamış").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                        Picker("Oturum", selection: $lectureID) { Text("Atanmamış").tag(UUID?.none); ForEach(eligibleLectures) { Text($0.title).tag(Optional($0.id)) } }
                    }
                }.frame(height: 300)
                Divider().overlay(PadTokens.phosphorDim)
                if kind == .markdown {
                    TextEditor(text: $bodyText)
                        .scrollContentBackground(.hidden).background(PadTokens.background)
                        .font(.system(.body, design: .monospaced)).padding(14)
                        .accessibilityLabel("Uzun not içeriği")
                } else {
                    PencilCanvasView(drawingData: $drawingData, backgroundColor: .black)
                        .accessibilityLabel("Apple Pencil çizim alanı")
                }
                HStack {
                    Text(kind == .markdown ? "Düz metin / Markdown • \(bodyText.lengthOfBytes(using: .utf8)) bayt" : "Ayrı yerel PencilKit tuvali")
                    Spacer(); Text(note == nil ? "İlk kayıt için Kaydet'e basın" : saveStatus)
                }
                .font(.caption.monospaced()).foregroundStyle(PadTokens.phosphorDim).padding(.horizontal, 16).padding(.vertical, 9)
                if let error { TerminalErrorState(message: error) }
            }
            .background(PadTokens.background).terminalPage().navigationTitle(note == nil ? "Yeni not" : "Not defteri")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { autosaveTask?.cancel(); dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save(dismissAfter: note == nil) } } }
        }.tint(PadTokens.phosphor)
            .onChange(of: bodyText) { _, _ in scheduleAutosave() }
            .onChange(of: drawingData) { _, _ in scheduleAutosave() }
            .onChange(of: title) { _, _ in scheduleAutosave() }
            .onChange(of: courseID) { _, _ in scheduleAutosave() }
            .onChange(of: lectureID) { _, _ in scheduleAutosave() }
            .onChange(of: pinned) { _, _ in scheduleAutosave() }
            .onDisappear { autosaveTask?.cancel() }
    }
    private func save(dismissAfter: Bool) {
        if let message = StudyNote.validationError(title: title) { error = message; return }
        guard NoteContentPolicy.isValid(body: bodyText) else { error = "Not 1 MB yerel güvenlik sınırını aşıyor."; return }
        if let note { note.title = title.trimmingCharacters(in: .whitespacesAndNewlines); note.body = bodyText; note.kind = kind; note.drawingData = kind == .handwritten ? drawingData : nil; note.courseID = courseID; note.lectureID = lectureID; note.isPinned = pinned; note.updatedAt = .now }
        else { context.insert(StudyNote(courseID: courseID, lectureID: lectureID, title: title, body: bodyText, kind: kind, drawingData: kind == .handwritten ? drawingData : nil, isPinned: pinned)) }
        do { try context.save(); error = nil; saveStatus = "Otomatik kaydedildi • \(Date.now.formatted(date: .omitted, time: .shortened))"; if dismissAfter { dismiss() } } catch { self.error = error.localizedDescription }
    }
    private func scheduleAutosave() {
        guard note != nil else { return }
        saveStatus = "Kaydediliyor…"; autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled else { return }
            await MainActor.run { save(dismissAfter: false) }
        }
    }
}
