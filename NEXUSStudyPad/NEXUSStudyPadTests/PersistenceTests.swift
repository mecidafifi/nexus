import XCTest
import SwiftData
@testable import NEXUSStudyPad

@MainActor
final class PersistenceTests: XCTestCase {
    func testCourseTaskAndLecturePersistInMemory() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Optimizasyon", code: "251141206")
        context.insert(course)
        context.insert(StudyTask(courseID: course.id, title: "Problem çöz"))
        context.insert(Lecture(courseID: course.id, title: "Birinci hafta", date: .now))
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).first?.courseID, course.id)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Lecture>()).first?.courseID, course.id)
    }

    func testInkAndHandwritingDataRoundTrip() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let bytes = Data([1, 2, 3, 4])
        let documentID = UUID()
        context.insert(PDFInkLayer(documentID: documentID, pageIndex: 2, drawingData: bytes))
        context.insert(StudyNote(title: "Çizim", kind: .handwritten, drawingData: bytes))
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<PDFInkLayer>()).first?.drawingData, bytes)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyNote>()).first?.drawingData, bytes)
    }

    func testTaskToggleCanBeSaved() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let task = StudyTask(title: "Okuma")
        context.insert(task); try context.save()
        task.isCompleted = true; task.updatedAt = .now; try context.save()
        XCTAssertTrue(try XCTUnwrap(context.fetch(FetchDescriptor<StudyTask>()).first).isCompleted)
    }
}
