import XCTest
@testable import NEXUSStudyPad

final class ModelValidationTests: XCTestCase {
    func testCourseRequiresName() {
        XCTAssertNotNil(Course.validationError(name: "   "))
        XCTAssertNil(Course.validationError(name: "Yapay Zeka"))
    }

    func testTaskRequiresTitle() {
        XCTAssertNotNil(StudyTask.validationError(title: "\n"))
        XCTAssertNil(StudyTask.validationError(title: "Makale oku"))
    }

    func testLectureRequiresCourseAndTitle() {
        XCTAssertNotNil(Lecture.validationError(title: "Oturum", courseID: nil))
        XCTAssertNotNil(Lecture.validationError(title: "", courseID: UUID()))
        XCTAssertNil(Lecture.validationError(title: "Hafta 1", courseID: UUID()))
    }

    func testEnumFallbacksAreSafe() {
        let lecture = Lecture(courseID: UUID(), title: "Ders", date: .now)
        lecture.attendanceRaw = "future-value"
        lecture.reviewRaw = "future-value"
        XCTAssertEqual(lecture.attendance, .unmarked)
        XCTAssertEqual(lecture.reviewStatus, .notReviewed)
    }
}
