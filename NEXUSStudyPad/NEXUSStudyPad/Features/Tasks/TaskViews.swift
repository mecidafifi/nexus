import SwiftUI
import SwiftData

struct TaskListView: View {
    @Query(sort: \StudyTask.createdAt, order: .reverse) private var tasks: [StudyTask]
    @Query(sort: \Course.name) private var courses: [Course]
    @Environment(\.modelContext) private var context
    @State private var showingNew = false
    @State private var editing: StudyTask?
    @State private var deleting: StudyTask?
    @State private var search = ""
    @State private var showCompleted = true
    private var filtered: [StudyTask] { tasks.filter { (showCompleted || !$0.isCompleted) && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.details.localizedCaseInsensitiveContains(search)) }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) } }
    private func courseName(_ id: UUID?) -> String? { courses.first { $0.id == id }?.name }

    var body: some View {
        NavigationStack {
            ZStack {
                TerminalBackground()
                if filtered.isEmpty { TerminalEmptyState(icon: "checklist", title: "Görev yok", message: search.isEmpty ? "İlk çalışma görevinizi ekleyin." : "Aramayla eşleşen görev yok.") }
                else {
                    List(filtered) { task in
                        HStack(spacing: 12) {
                            Button { toggle(task) } label: { Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square").font(.title2).frame(width: PadTokens.minimumTap, height: PadTokens.minimumTap) }
                                .buttonStyle(.plain).accessibilityLabel("\(task.title), \(task.isCompleted ? "tamamlandı" : "tamamlanmadı")").accessibilityHint("Durumu değiştirir")
                            Button { editing = task } label: {
                                VStack(alignment: .leading, spacing: 5) { Text(task.title).font(.headline).strikethrough(task.isCompleted); HStack { if let name = courseName(task.courseID) { Text(name) }; if let due = task.dueDate { Text(due.formatted(date: .abbreviated, time: .shortened)) } }.font(.caption).foregroundStyle(PadTokens.phosphorDim) }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }.swipeActions { Button(role: .destructive) { deleting = task } label: { Label("Sil", systemImage: "trash") } }
                    }.scrollContentBackground(.hidden)
                }
            }.terminalPage().navigationTitle("Görevler")
                .searchable(text: $search, prompt: "Görev ara")
                .toolbar { ToolbarItem { Toggle(isOn: $showCompleted) { Label("Tamamlananları göster", systemImage: "checkmark.circle") } }; ToolbarItem { Button { showingNew = true } label: { Label("Yeni görev", systemImage: "plus") } } }
                .sheet(isPresented: $showingNew) { TaskEditor(courses: courses) }
                .sheet(item: $editing) { TaskEditor(task: $0, courses: courses) }
                .alert("Görev silinsin mi?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) { Button("Vazgeç", role: .cancel) { deleting = nil }; Button("Sil", role: .destructive) { if let deleting { context.delete(deleting); try? context.save() }; deleting = nil } } message: { Text("Bu işlem geri alınamaz.") }
        }
    }
    private func toggle(_ task: StudyTask) { task.isCompleted.toggle(); task.updatedAt = .now; try? context.save() }
}

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let task: StudyTask?
    let courses: [Course]
    @State private var title: String
    @State private var details: String
    @State private var courseID: UUID?
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var error: String?
    init(task: StudyTask? = nil, courses: [Course], initialCourseID: UUID? = nil) {
        self.task = task; self.courses = courses
        _title = State(initialValue: task?.title ?? ""); _details = State(initialValue: task?.details ?? ""); _courseID = State(initialValue: task?.courseID ?? initialCourseID)
        _hasDueDate = State(initialValue: task?.dueDate != nil); _dueDate = State(initialValue: task?.dueDate ?? .now)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Görev başlığı", text: $title)
                TextField("Açıklama", text: $details, axis: .vertical).lineLimit(3...8)
                Picker("Ders (isteğe bağlı)", selection: $courseID) { Text("Atanmamış").tag(UUID?.none); ForEach(courses) { Text($0.name).tag(Optional($0.id)) } }
                Toggle("Son tarih ekle", isOn: $hasDueDate)
                if hasDueDate { DatePicker("Son tarih", selection: $dueDate) }
                if let error { TerminalErrorState(message: error) }
            }.navigationTitle(task == nil ? "Yeni görev" : "Görevi düzenle")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Kaydet") { save() } } }
        }.tint(PadTokens.phosphor)
    }
    private func save() {
        if let message = StudyTask.validationError(title: title) { error = message; return }
        if let task { task.title = title.trimmingCharacters(in: .whitespacesAndNewlines); task.details = details; task.courseID = courseID; task.dueDate = hasDueDate ? dueDate : nil; task.updatedAt = .now }
        else { context.insert(StudyTask(courseID: courseID, title: title, details: details, dueDate: hasDueDate ? dueDate : nil)) }
        do { try context.save(); dismiss() } catch { self.error = error.localizedDescription }
    }
}
