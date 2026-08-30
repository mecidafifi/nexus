import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class OrganizationTests: XCTestCase {
    func testProjectTaskSubtaskCRUDAndProgress() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let viewModel = OrganizationViewModel()
        try viewModel.saveProject(nil, title: " Mezuniyet Projesi ", details: "Yerel", dueDate: .now, priority: .critical, status: .active, context: context)
        let project = try XCTUnwrap(context.fetch(FetchDescriptor<ProjectRecord>()).first)
        XCTAssertEqual(project.title, "Mezuniyet Projesi")

        try viewModel.saveTask(nil, projectID: project.id, parentTaskID: nil, title: "Rapor", details: "Taslak", dueDate: .now, priority: .high, status: .active, context: context)
        let parent = try XCTUnwrap(context.fetch(FetchDescriptor<OrganizationTask>()).first)
        try viewModel.saveTask(nil, projectID: project.id, parentTaskID: parent.id, title: "Kaynakça", details: "", dueDate: nil, priority: .normal, status: .completed, allTasks: [parent], context: context)
        let tasks = try context.fetch(FetchDescriptor<OrganizationTask>())
        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(viewModel.progress(tasks: tasks, projectID: project.id), OrganizationProgress(completed: 1, total: 2))

        try viewModel.deleteTask(parent, allTasks: tasks, context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<OrganizationTask>()).isEmpty)
    }

    func testSearchFilterSortAndCancelledProgressSemantics() {
        let viewModel = OrganizationViewModel()
        let project = ProjectRecord(title: "NEXUS")
        let high = OrganizationTask(projectID: project.id, title: "Yayın", details: "Mac", priority: .critical, status: .active)
        let cancelled = OrganizationTask(projectID: project.id, title: "Eski", priority: .low, status: .cancelled)
        let complete = OrganizationTask(projectID: project.id, title: "Test", priority: .high, status: .completed)
        viewModel.searchText = "mac"
        XCTAssertEqual(viewModel.filteredTasks([cancelled, complete, high], projectID: project.id).map(\.id), [high.id])
        viewModel.searchText = ""; viewModel.priorityFilter = .high
        XCTAssertEqual(viewModel.filteredTasks([cancelled, complete, high], projectID: project.id).map(\.id), [complete.id])
        XCTAssertEqual(viewModel.progress(tasks: [cancelled, complete, high], projectID: project.id), OrganizationProgress(completed: 1, total: 2))
    }

    func testValidationRejectsEmptyTitleAndParentCycle() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let viewModel = OrganizationViewModel()
        XCTAssertThrowsError(try viewModel.saveProject(nil, title: "  ", details: "", dueDate: nil, priority: .normal, status: .planned, context: context))
        let projectID = UUID()
        let parent = OrganizationTask(projectID: projectID, title: "Üst")
        let child = OrganizationTask(projectID: projectID, parentTaskID: parent.id, title: "Alt")
        XCTAssertThrowsError(try viewModel.saveTask(parent, projectID: projectID, parentTaskID: child.id, title: parent.title, details: "", dueDate: nil, priority: .normal, status: .active, allTasks: [parent, child], context: context))
    }

    func testVersionSixBackupRoundTripsOrganizationAndRejectsDanglingParent() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        let project = ProjectRecord(title: "Yayın", priority: .high, status: .active)
        let task = OrganizationTask(projectID: project.id, title: "Paketle", priority: .critical)
        source.mainContext.insert(project); source.mainContext.insert(task); try source.mainContext.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: source.mainContext)))
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertEqual(backup.organizationProjects?.first?.title, "Yayın")
        XCTAssertEqual(backup.organizationTasks?.first?.projectID, project.id)
        let target = try PersistenceController.makeContainer(inMemory: true)
        try BackupService.apply(backup, mode: .replace, to: target.mainContext)
        XCTAssertEqual(try target.mainContext.fetch(FetchDescriptor<OrganizationTask>()).first?.title, "Paketle")

        var invalid = NEXUSBackup(schemaVersion: 6, createdAt: .now, courses: [], tasks: [], goals: [], sessions: [])
        invalid.organizationProjects = [.init(id: project.id, title: "P", details: "", dueDate: nil, isArchived: false, priority: "normal", status: "active", createdAt: .now, updatedAt: .now)]
        invalid.organizationTasks = [.init(id: UUID(), projectID: project.id, parentTaskID: UUID(), title: "T", details: "", dueDate: nil, priority: "normal", status: "active", order: 0, overdueReviewedAt: nil, createdAt: .now, updatedAt: .now)]
        XCTAssertThrowsError(try BackupService.validate(invalid))
    }
}
