import SwiftUI
import SwiftData

struct NotesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var context
    @Query private var notes: [NexusNote]
    @Query(sort: \NoteFolder.name) private var folders: [NoteFolder]
    @Query(sort: \NoteTag.name) private var tags: [NoteTag]
    @Query private var assignments: [NoteTagAssignment]
    @StateObject private var viewModel = NotesViewModel()
    @State private var selectedNoteID: UUID?
    @State private var deletion: NotesDeletion?
    @State private var nameDialog: NoteNameDialogKind?
    @FocusState private var searchFocused: Bool

    private var rows: [NexusNote] { viewModel.filteredNotes(notes, assignments: assignments) }

    var body: some View {
        VStack(spacing: 0) {
            TerminalHeader(titleKey: "route.notes", subtitleKey: "notes.subtitle", onBack: appState.goHome)
            HStack(spacing: 0) {
                sidebar
                Divider().overlay(TerminalTokens.border)
                noteList
                Divider().overlay(TerminalTokens.border)
                detail
            }
            if let error = viewModel.errorMessage { HStack { Image(systemName: "xmark.octagon"); Text(error); Spacer() }.foregroundStyle(TerminalTokens.error).padding(.horizontal, 12).frame(height: 28).background(TerminalTokens.surface) }
            else { TerminalStatusBar(messageKey: viewModel.statusMessageKey, kind: viewModel.statusMessageKey == "notes.status.autosaved" ? .success : .neutral) }
        }
        .sheet(item: $nameDialog) { NoteNameDialog(kind: $0, viewModel: viewModel) }
        .confirmationDialog("delete.confirm.title", isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
            Button("action.delete", role: .destructive) { performDelete() }
            Button("action.cancel", role: .cancel) { deletion = nil }
        } message: { Text("delete.confirm.message") }
        .onReceive(NotificationCenter.default.publisher(for: .nexusNewItem)) { _ in createNote() }
        .onReceive(NotificationCenter.default.publisher(for: .nexusFocusSearch)) { _ in searchFocused = true }
        .accessibilityIdentifier("notes.screen")
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Button { viewModel.selectedFolderID = nil; viewModel.selectedTagID = nil; viewModel.pinnedOnly = false } label: { Label("notes.all", systemImage: "note.text").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).padding(8)
                Button { viewModel.pinnedOnly.toggle(); viewModel.selectedFolderID = nil; viewModel.selectedTagID = nil } label: { Label("notes.pinned", systemImage: "pin").frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.plain).padding(8).background(viewModel.pinnedOnly ? TerminalTokens.phosphor.opacity(0.12) : .clear)
                sidebarHeading("notes.folders", action: { nameDialog = .folder })
                ForEach(folders) { folder in
                    Button { viewModel.selectedFolderID = folder.id; viewModel.selectedTagID = nil; viewModel.pinnedOnly = false } label: { HStack { Image(systemName: "folder"); Text(folder.name); Spacer(); Text("\(notes.filter { $0.folderID == folder.id }.count)") } }.buttonStyle(.plain).padding(8).background(viewModel.selectedFolderID == folder.id ? TerminalTokens.phosphor.opacity(0.12) : .clear).contextMenu { Button("action.delete", role: .destructive) { deletion = .folder(folder.id) } }
                }
                sidebarHeading("notes.tags", action: { nameDialog = .tag })
                ForEach(tags) { tag in
                    Button { viewModel.selectedTagID = tag.id; viewModel.selectedFolderID = nil; viewModel.pinnedOnly = false } label: { HStack { Image(systemName: "number"); Text(tag.name); Spacer() } }.buttonStyle(.plain).padding(8).background(viewModel.selectedTagID == tag.id ? TerminalTokens.phosphor.opacity(0.12) : .clear).contextMenu { Button("action.delete", role: .destructive) { deletion = .tag(tag.id) } }
                }
            }.padding(8)
        }.frame(width: 190).background(TerminalTokens.surface.opacity(0.45))
    }

    private func sidebarHeading(_ key: String, action: @escaping () -> Void) -> some View {
        HStack { Text(LocalizedStringKey(key)).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted); Spacer(); Button(action: action) { Image(systemName: "plus") }.buttonStyle(.plain).accessibilityLabel(Text("action.new")) }.padding(.horizontal, 8).padding(.top, 10)
    }

    private var noteList: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "magnifyingglass"); TextField("notes.search", text: $viewModel.searchText).textFieldStyle(.plain).focused($searchFocused); Picker("notes.sort", selection: $viewModel.sort) { ForEach(NoteSort.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) } }.frame(width: 120); Button(action: createNote) { Image(systemName: "square.and.pencil") }.buttonStyle(TerminalPrimaryButtonStyle()).accessibilityLabel(Text("notes.new")) }.padding(10).frame(height: 52)
            if rows.isEmpty { TerminalEmptyState(titleKey: "notes.empty.title", messageKey: "notes.empty.message", actionKey: "notes.new", action: createNote) }
            else {
                List(selection: $selectedNoteID) { ForEach(rows) { note in
                    VStack(alignment: .leading, spacing: 4) { HStack { if note.isPinned { Image(systemName: "pin.fill").accessibilityLabel(Text("notes.pinned")) }; Text(note.title).fontWeight(.semibold).lineLimit(1); Spacer() }; Text(note.body.replacingOccurrences(of: "\n", with: " ")).font(.caption).foregroundStyle(TerminalTokens.phosphorMuted).lineLimit(2); Text(note.updatedAt, style: .relative).font(.caption2) }
                        .padding(.vertical, 5).tag(note.id).contextMenu { Button(LocalizedStringKey(note.isPinned ? "notes.unpin" : "notes.pin")) { togglePin(note) }; Button("action.delete", role: .destructive) { deletion = .note(note.id) } }
                } }.listStyle(.sidebar).scrollContentBackground(.hidden)
            }
        }.frame(minWidth: 280, idealWidth: 330, maxWidth: 400)
    }

    @ViewBuilder private var detail: some View {
        if let note = notes.first(where: { $0.id == selectedNoteID }) { NoteDetailView(note: note, folders: folders, tags: tags, assignments: assignments, viewModel: viewModel).id(note.id) }
        else { TerminalEmptyState(titleKey: "notes.select.title", messageKey: "notes.select.message") }
    }

    private func createNote() { do { let note = try viewModel.createNote(folderID: viewModel.selectedFolderID, context: context); selectedNoteID = note.id } catch { viewModel.errorMessage = error.localizedDescription } }
    private func togglePin(_ note: NexusNote) { do { try viewModel.update(note, title: note.title, body: note.body, folderID: note.folderID, isPinned: !note.isPinned, context: context) } catch { viewModel.errorMessage = error.localizedDescription } }
    private func performDelete() {
        guard let deletion else { return }
        do { switch deletion {
        case .note(let id): if let value = notes.first(where: { $0.id == id }) { try viewModel.deleteNote(value, assignments: assignments, context: context); if selectedNoteID == id { selectedNoteID = nil } }
        case .folder(let id): if let value = folders.first(where: { $0.id == id }) { try viewModel.deleteFolder(value, notes: notes, context: context); viewModel.selectedFolderID = nil }
        case .tag(let id): if let value = tags.first(where: { $0.id == id }) { try viewModel.deleteTag(value, assignments: assignments, context: context); viewModel.selectedTagID = nil }
        } } catch { viewModel.errorMessage = error.localizedDescription }
        self.deletion = nil
    }
}

private enum NotesDeletion { case note(UUID), folder(UUID), tag(UUID) }
enum NoteNameDialogKind: String, Identifiable { case folder, tag; var id: String { rawValue } }

private struct NoteNameDialog: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let kind: NoteNameDialogKind
    @ObservedObject var viewModel: NotesViewModel
    @State private var name = ""
    @State private var error: String?
    var body: some View { TerminalWindow { TerminalDialog(titleKey: kind == .folder ? "notes.folder.new" : "notes.tag.new") { TextField(LocalizedStringKey(kind == .folder ? "notes.folder.name" : "notes.tag.name"), text: $name); if let error { Text(error).foregroundStyle(TerminalTokens.error) }; HStack { Spacer(); Button("action.cancel") { dismiss() }.buttonStyle(TerminalButtonStyle()); Button("action.save") { save() }.buttonStyle(TerminalPrimaryButtonStyle()) } }.padding() }.frame(width: 440, height: 210) }
    private func save() { do { if kind == .folder { try viewModel.createFolder(name: name, context: context) } else { try viewModel.createTag(name: name, context: context) }; dismiss() } catch { self.error = error.localizedDescription } }
}
