import XCTest
import SwiftData
@testable import NEXUSStudyPad

@MainActor
final class CourseScheduleTests: XCTestCase {
    func testScheduleRulePersistsEditsAndDeletion() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Fizik I")
        let rule = CourseScheduleRule(courseID: course.id, weekday: 6, startMinutes: 495, durationMinutes: 165, location: "Lab")
        context.insert(course)
        context.insert(rule)
        try context.save()

        let persisted = try XCTUnwrap(context.fetch(FetchDescriptor<CourseScheduleRule>()).first)
        persisted.startMinutes = 540
        persisted.durationMinutes = 90
        persisted.isActive = false
        try context.save()

        let edited = try XCTUnwrap(context.fetch(FetchDescriptor<CourseScheduleRule>()).first)
        XCTAssertEqual(edited.startMinutes, 540)
        XCTAssertEqual(edited.durationMinutes, 90)
        XCTAssertFalse(edited.isActive)

        context.delete(edited)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<CourseScheduleRule>()).isEmpty)
    }

    func testDeletingCourseRemovesOnlyDependentRulesAndUnlinksContent() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Robotik")
        let otherCourse = Course(name: "Yapay Zeka")
        let lecture = Lecture(courseID: course.id, title: "Hafta 1", date: .now)
        let task = StudyTask(courseID: course.id, title: "Ödev")
        let ownedRule = CourseScheduleRule(courseID: course.id, weekday: 3, startMinutes: 600)
        let otherRule = CourseScheduleRule(courseID: otherCourse.id, weekday: 4, startMinutes: 700)
        [course, otherCourse].forEach(context.insert)
        context.insert(lecture)
        context.insert(task)
        context.insert(ownedRule)
        context.insert(otherRule)
        try context.save()

        try CourseDeletionService.delete(course, context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).map(\.name), ["Yapay Zeka"])
        XCTAssertNil(try context.fetch(FetchDescriptor<Lecture>()).first?.courseID)
        XCTAssertNil(try context.fetch(FetchDescriptor<StudyTask>()).first?.courseID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CourseScheduleRule>()).map(\.id), [otherRule.id])
    }

    func testScheduleValidationRejectsImpossibleValues() {
        let now = Date.now
        XCTAssertFalse(CourseScheduleRule.isValid(weekday: 0, startMinutes: 600, durationMinutes: 50, effectiveStart: now, effectiveEnd: nil))
        XCTAssertFalse(CourseScheduleRule.isValid(weekday: 2, startMinutes: 1_440, durationMinutes: 50, effectiveStart: now, effectiveEnd: nil))
        XCTAssertFalse(CourseScheduleRule.isValid(weekday: 2, startMinutes: 600, durationMinutes: 5, effectiveStart: now, effectiveEnd: nil))
        XCTAssertFalse(CourseScheduleRule.isValid(weekday: 2, startMinutes: 600, durationMinutes: 50, effectiveStart: now, effectiveEnd: now.addingTimeInterval(-1)))
    }
}
