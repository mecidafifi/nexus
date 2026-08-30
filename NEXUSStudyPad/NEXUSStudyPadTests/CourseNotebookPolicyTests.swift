import XCTest
import SwiftData
@testable import NEXUSStudyPad

@MainActor
final class CourseNotebookPolicyTests: XCTestCase {
    func testCourseAndLectureDefaultsProvideFifteenWeekNotebook() {
        let course = Course(name: "Bilimsel Araştırma")
        let lecture = Lecture(courseID: course.id, title: "Giriş", date: .now)
        XCTAssertEqual(course.semesterWeekCount, 15)
        XCTAssertEqual(lecture.weekNumber, 1)
        XCTAssertEqual(lecture.lessonNumber, 1)
    }

    func testWeekGroupingOrdersLessonsAndSuggestsNextNumber() {
        let courseID = UUID()
        let second = Lecture(courseID: courseID, title: "İkinci", date: .now, weekNumber: 4, lessonNumber: 2)
        let first = Lecture(courseID: courseID, title: "Birinci", date: .now, weekNumber: 4, lessonNumber: 1)
        let otherWeek = Lecture(courseID: courseID, title: "Başka hafta", date: .now, weekNumber: 5, lessonNumber: 1)
        let grouped = CourseNotebookPolicy.lectures(for: courseID, week: 4, from: [second, otherWeek, first])
        XCTAssertEqual(grouped.map(\.title), ["Birinci", "İkinci"])
        XCTAssertEqual(CourseNotebookPolicy.nextLessonNumber(for: courseID, week: 4, from: [second, otherWeek, first]), 3)
    }

    func testDuplicateIsScopedToCourseWeekAndLesson() {
        let courseID = UUID()
        let existing = Lecture(courseID: courseID, title: "Birinci", date: .now, weekNumber: 3, lessonNumber: 2)
        XCTAssertTrue(CourseNotebookPolicy.hasDuplicate(courseID: courseID, week: 3, lesson: 2, excluding: nil, in: [existing]))
        XCTAssertFalse(CourseNotebookPolicy.hasDuplicate(courseID: courseID, week: 3, lesson: 1, excluding: nil, in: [existing]))
        XCTAssertFalse(CourseNotebookPolicy.hasDuplicate(courseID: courseID, week: 3, lesson: 2, excluding: existing.id, in: [existing]))
    }

    func testLectureNotebookTextPersistsWithItsSession() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let course = Course(name: "Robotik")
        let lecture = Lecture(courseID: course.id, title: "Sensörler", date: .now, note: "İlk satır", weekNumber: 7, lessonNumber: 2)
        container.mainContext.insert(course)
        container.mainContext.insert(lecture)
        try container.mainContext.save()

        lecture.note = "İlk satır\nİkinci satır\nSınav notu"
        try container.mainContext.save()

        let stored = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<Lecture>()).first)
        XCTAssertEqual(stored.weekNumber, 7)
        XCTAssertEqual(stored.lessonNumber, 2)
        XCTAssertEqual(stored.note, "İlk satır\nİkinci satır\nSınav notu")
    }

    func testLectureValidationRejectsWeekOutsideCourseAndInvalidLesson() {
        XCTAssertNotNil(Lecture.validationError(title: "Ders", courseID: UUID(), weekNumber: 16, lessonNumber: 1, semesterWeekCount: 15))
        XCTAssertNotNil(Lecture.validationError(title: "Ders", courseID: UUID(), weekNumber: 1, lessonNumber: 11, semesterWeekCount: 15))
        XCTAssertNil(Lecture.validationError(title: "Ders", courseID: UUID(), weekNumber: 15, lessonNumber: 2, semesterWeekCount: 15))
    }
}
