import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class StudyCRUDTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: StudyViewModel!

    override func setUpWithError() throws {
        container = try PersistenceController.makeContainer(inMemory: true)
        context = container.mainContext
        viewModel = StudyViewModel()
    }

    func testCourseCreateUpdateDeletePersists() throws {
        try viewModel.saveCourse(nil, name: "Algoritmalar", code: "CS201", instructor: "Ada", location: "B-12", context: context)
        var courses = try context.fetch(FetchDescriptor<Course>())
        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(courses[0].name, "Algoritmalar")

        try viewModel.saveCourse(courses[0], name: "İleri Algoritmalar", code: "CS301", instructor: "Ada", location: "B-12", context: context)
        courses = try context.fetch(FetchDescriptor<Course>())
        XCTAssertEqual(courses[0].code, "CS301")

        try viewModel.delete(courses[0], context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Course>()).isEmpty)
    }

    func testAllStudyRecordTypesPersistAndLinkByCourseID() throws {
        try viewModel.saveCourse(nil, name: "Matematik", code: "M101", instructor: "", location: "", context: context)
        let course = try XCTUnwrap(context.fetch(FetchDescriptor<Course>()).first)
        try viewModel.saveTask(nil, title: "Problem seti", details: "1-20", courseID: course.id, hasDueDate: true, dueDate: .now, status: .inProgress, priority: .high, estimatedMinutes: 90, context: context)
        try viewModel.saveGoal(nil, title: "Haftalık matematik", courseID: course.id, targetMinutes: 300, period: .weekly, startDate: .now.addingTimeInterval(-60), endDate: .now.addingTimeInterval(604800), context: context)
        try viewModel.saveSession(nil, courseID: course.id, startedAt: .now, durationMinutes: 75, note: "Türev", context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).first?.courseID, course.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyGoal>()).first?.targetMinutes, 300)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudySession>()).first?.durationMinutes, 75)
    }

    func testValidationRejectsInvalidRecords() throws {
        XCTAssertThrowsError(try viewModel.saveCourse(nil, name: "  ", code: "", instructor: "", location: "", context: context))
        XCTAssertThrowsError(try viewModel.saveSession(nil, courseID: nil, startedAt: .now, durationMinutes: 0, note: "", context: context))
        XCTAssertThrowsError(try viewModel.saveGoal(nil, title: "Hedef", courseID: nil, targetMinutes: 10, period: .weekly, startDate: .now, endDate: .distantPast, context: context))
    }
}
