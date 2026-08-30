import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class NotesTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: NotesViewModel!

    override func setUpWithError() throws { container = try PersistenceController.makeContainer(inMemory: true); context = container.mainContext; viewModel = NotesViewModel() }

    func testNoteFolderTagCRUDAndAssignments() throws {
        try viewModel.createFolder(name: "Dersler", context: context)
        try viewModel.createTag(name: "Sınav", context: context)
        let folder = try XCTUnwrap(context.fetch(FetchDescriptor<NoteFolder>()).first)
        let tag = try XCTUnwrap(context.fetch(FetchDescriptor<NoteTag>()).first)
        let note = try viewModel.createNote(folderID: folder.id, context: context)
        try viewModel.update(note, title: "Final özeti", body: "Konular", folderID: folder.id, isPinned: true, context: context)
        try viewModel.toggleTag(tag.id, for: note.id, assignments: [], context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<NexusNote>()).first?.title, "Final özeti")
        XCTAssertTrue(note.isPinned)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NoteTagAssignment>()).first?.noteID, note.id)
    }

    func testFolderDeletionKeepsNotesAndNullifiesLink() throws {
        try viewModel.createFolder(name: "Geçici", context: context)
        let folder = try XCTUnwrap(context.fetch(FetchDescriptor<NoteFolder>()).first)
        let note = try viewModel.createNote(folderID: folder.id, context: context)
        try viewModel.deleteFolder(folder, notes: [note], context: context)
        XCTAssertNil(note.folderID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NexusNote>()).count, 1)
    }

    func testSearchTagFilterAndPinnedFirstSort() throws {
        let tagID = UUID()
        let pinned = NexusNote(title: "Algoritma", body: "Graf", isPinned: true)
        let regular = NexusNote(title: "Fizik", body: "Dalga")
        let assignment = NoteTagAssignment(noteID: regular.id, tagID: tagID)
        viewModel.selectedTagID = tagID
        XCTAssertEqual(viewModel.filteredNotes([pinned, regular], assignments: [assignment]).map(\.id), [regular.id])
        viewModel.selectedTagID = nil
        XCTAssertEqual(viewModel.filteredNotes([regular, pinned], assignments: []).first?.id, pinned.id)
    }

    func testBlankTitlesAndNamesAreRejected() throws {
        let note = try viewModel.createNote(folderID: nil, context: context)
        XCTAssertThrowsError(try viewModel.update(note, title: "  ", body: "", folderID: nil, isPinned: false, context: context))
        XCTAssertThrowsError(try viewModel.createFolder(name: "", context: context))
    }
}
