import Foundation
import SwiftData

enum NoteSort: String, CaseIterable, Identifiable {
    case updated, created, title
    var id: String { rawValue }
    var titleKey: String { "notes.sort.\(rawValue)" }
}

@MainActor
final class NotesViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedFolderID: UUID?
    @Published var selectedTagID: UUID?
    @Published var pinnedOnly = false
    @Published var sort: NoteSort = .updated
    @Published var statusMessageKey = "status.ready"
    @Published var errorMessage: String?

    func filteredNotes(_ notes: [NexusNote], assignments: [NoteTagAssignment]) -> [NexusNote] {
        let taggedNoteIDs = selectedTagID.map { tagID in Set(assignments.filter { $0.tagID == tagID }.map(\.noteID)) }
        return notes.filter { note in
            let matchesSearch = searchText.isEmpty || note.title.localizedCaseInsensitiveContains(searchText) || note.body.localizedCaseInsensitiveContains(searchText)
            let matchesFolder = selectedFolderID == nil || note.folderID == selectedFolderID
            let matchesTag = taggedNoteIDs == nil || taggedNoteIDs!.contains(note.id)
            let matchesPin = !pinnedOnly || note.isPinned
            return matchesSearch && matchesFolder && matchesTag && matchesPin
        }.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            switch sort {
            case .updated: return lhs.updatedAt > rhs.updatedAt
            case .created: return lhs.createdAt > rhs.createdAt
            case .title: return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func createNote(folderID: UUID?, context: ModelContext) throws -> NexusNote {
        let note = NexusNote(title: String(localized: "notes.untitled"), folderID: folderID)
        context.insert(note); try commit(context); return note
    }

    func update(_ note: NexusNote, title: String, body: String, folderID: UUID?, isPinned: Bool, context: ModelContext) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw NotesValidationError.emptyTitle }
        note.title = cleanTitle; note.body = body; note.folderID = folderID; note.isPinned = isPinned; note.updatedAt = .now
        try commit(context, status: "notes.status.autosaved")
    }

    func createFolder(name: String, context: ModelContext) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw NotesValidationError.emptyName }
        context.insert(NoteFolder(name: clean)); try commit(context)
    }

    func createTag(name: String, context: ModelContext) throws {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw NotesValidationError.emptyName }
        context.insert(NoteTag(name: clean)); try commit(context)
    }

    func toggleTag(_ tagID: UUID, for noteID: UUID, assignments: [NoteTagAssignment], context: ModelContext) throws {
        if let existing = assignments.first(where: { $0.tagID == tagID && $0.noteID == noteID }) { context.delete(existing) }
        else { context.insert(NoteTagAssignment(noteID: noteID, tagID: tagID)) }
        try commit(context)
    }

    func deleteNote(_ note: NexusNote, assignments: [NoteTagAssignment], context: ModelContext) throws {
        assignments.filter { $0.noteID == note.id }.forEach(context.delete); context.delete(note); try commit(context)
    }

    func deleteFolder(_ folder: NoteFolder, notes: [NexusNote], context: ModelContext) throws {
        notes.filter { $0.folderID == folder.id }.forEach { $0.folderID = nil; $0.updatedAt = .now }
        context.delete(folder); try commit(context)
    }

    func deleteTag(_ tag: NoteTag, assignments: [NoteTagAssignment], context: ModelContext) throws {
        assignments.filter { $0.tagID == tag.id }.forEach(context.delete); context.delete(tag); try commit(context)
    }

    private func commit(_ context: ModelContext, status: String = "status.saved") throws {
        do { try context.save(); errorMessage = nil; statusMessageKey = status }
        catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error }
    }
}

enum NotesValidationError: LocalizedError {
    case emptyTitle, emptyName
    var errorDescription: String? { switch self { case .emptyTitle: String(localized: "validation.titleRequired"); case .emptyName: String(localized: "notes.validation.nameRequired") } }
}
