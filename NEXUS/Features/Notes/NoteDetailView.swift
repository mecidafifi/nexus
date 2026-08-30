import SwiftUI
import SwiftData

struct NoteDetailView: View {
    @Environment(\.modelContext) private var context
    let note: NexusNote
    let folders: [NoteFolder]
    let tags: [NoteTag]
    let assignments: [NoteTagAssignment]
    @ObservedObject var viewModel: NotesViewModel
    @State private var title: String
    @State private var bodyText: String
    @State private var folderID: UUID?
    @State private var isPinned: Bool
    @State private var saveTask: Task<Void, Never>?
    @State private var validationMessage: String?

    init(note: NexusNote, folders: [NoteFolder], tags: [NoteTag], assignments: [NoteTagAssignment], viewModel: NotesViewModel) {
        self.note = note; self.folders = folders; self.tags = tags; self.assignments = assignments; self.viewModel = viewModel
        _title = State(initialValue: note.title); _bodyText = State(initialValue: note.body); _folderID = State(initialValue: note.folderID); _isPinned = State(initialValue: note.isPinned)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("notes.title", text: $title).textFieldStyle(.plain).font(.system(.title2, design: .monospaced, weight: .bold))
                Toggle(isOn: $isPinned) { Image(systemName: isPinned ? "pin.fill" : "pin") }.toggleStyle(.button).help(Text("notes.pin"))
                Picker("notes.folder", selection: $folderID) { Text("notes.noFolder").tag(UUID?.none); ForEach(folders) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 160)
            }.padding(14).background(TerminalTokens.surface.opacity(0.5))
            ScrollView(.horizontal) { HStack { ForEach(tags) { tag in
                let assigned = assignments.contains { $0.noteID == note.id && $0.tagID == tag.id }
                Button { toggle(tag.id) } label: { Label(tag.name, systemImage: assigned ? "checkmark.circle.fill" : "circle") }.buttonStyle(TerminalButtonStyle()).accessibilityValue(Text(assigned ? "notes.tag.assigned" : "notes.tag.notAssigned"))
            } }.padding(.horizontal, 14).padding(.vertical, 8) }
            TextEditor(text: $bodyText).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(12).background(TerminalTokens.background).accessibilityLabel(Text("notes.body"))
            HStack { if let validationMessage { Label(validationMessage, systemImage: "exclamationmark.triangle").foregroundStyle(TerminalTokens.warning) } else { Label("notes.status.autosave", systemImage: "arrow.triangle.2.circlepath") }; Spacer(); Text(note.updatedAt, style: .time).monospacedDigit() }.font(.caption).padding(10).background(TerminalTokens.surface)
        }
        .onChange(of: title) { scheduleSave() }.onChange(of: bodyText) { scheduleSave() }.onChange(of: folderID) { scheduleSave() }.onChange(of: isPinned) { scheduleSave() }
        .onReceive(NotificationCenter.default.publisher(for: .nexusSave)) { _ in saveNow() }
        .onDisappear { saveTask?.cancel(); saveNow() }
    }

    private func scheduleSave() {
        saveTask?.cancel(); saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500)); if !Task.isCancelled { saveNow() }
        }
    }
    private func saveNow() { do { try viewModel.update(note, title: title, body: bodyText, folderID: folderID, isPinned: isPinned, context: context); validationMessage = nil } catch { validationMessage = error.localizedDescription } }
    private func toggle(_ tagID: UUID) { do { try viewModel.toggleTag(tagID, for: note.id, assignments: assignments, context: context) } catch { viewModel.errorMessage = error.localizedDescription } }
}
