import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class OBSTests: XCTestCase {
    func testWeightedCourseAverageNormalizesEnteredWeights() throws {
        let viewModel = OBSViewModel(); let course = UUID()
        let midterm = OBSAssessment(universityCourseID: course, title: "Vize", maximumPoints: 100, earnedPoints: 80, weightPercent: 40)
        let final = OBSAssessment(universityCourseID: course, title: "Final", maximumPoints: 100, earnedPoints: 90, weightPercent: 60)
        XCTAssertEqual(try XCTUnwrap(viewModel.courseAverage(courseID: course, assessments: [midterm, final])), 86, accuracy: 0.001)
    }

    func testZeroWeightsUseArithmeticMeanAndIgnoreUngraded() throws {
        let viewModel = OBSViewModel(); let course = UUID()
        let a = OBSAssessment(universityCourseID: course, title: "A", maximumPoints: 50, earnedPoints: 40)
        let b = OBSAssessment(universityCourseID: course, title: "B", maximumPoints: 100, earnedPoints: 60)
        let future = OBSAssessment(universityCourseID: course, title: "C", earnedPoints: nil)
        XCTAssertEqual(try XCTUnwrap(viewModel.courseAverage(courseID: course, assessments: [a, b, future])), 70, accuracy: 0.001)
    }

    func testCreditWeightedGPAUsesConfiguredBands() throws {
        let viewModel = OBSViewModel(); let c1 = UniversityCourse(name: "A", creditHours: 3); let c2 = UniversityCourse(name: "B", creditHours: 1)
        let assessments = [OBSAssessment(universityCourseID: c1.id, title: "Final", earnedPoints: 90), OBSAssessment(universityCourseID: c2.id, title: "Final", earnedPoints: 70)]
        let bands = [GradeScaleBand(letter: "AA", minimumPercent: 85, gradePoints: 4), GradeScaleBand(letter: "CC", minimumPercent: 65, gradePoints: 2)]
        let result = try XCTUnwrap(viewModel.gpa(courses: [c1, c2], assessments: assessments, bands: bands))
        XCTAssertEqual(result.gpa, 3.5, accuracy: 0.001); XCTAssertEqual(result.gradedCredits, 4)
    }

    func testUpcomingIncludesOnlyFutureUngradedAssessments() {
        let viewModel = OBSViewModel(); let course = UUID(); let now = Date.now
        let upcoming = OBSAssessment(universityCourseID: course, title: "Final", dueDate: now.addingTimeInterval(86400), earnedPoints: nil)
        let graded = OBSAssessment(universityCourseID: course, title: "Vize", dueDate: now.addingTimeInterval(86400), earnedPoints: 80)
        let past = OBSAssessment(universityCourseID: course, title: "Quiz", dueDate: now.addingTimeInterval(-86400), earnedPoints: nil)
        XCTAssertEqual(viewModel.upcoming([graded, past, upcoming], now: now).map(\.id), [upcoming.id])
    }

    func testOBSCRUDValidationAndCascade() throws {
        let container = try PersistenceController.makeContainer(inMemory: true); let context = container.mainContext; let viewModel = OBSViewModel()
        try viewModel.saveCourse(nil, name: "İstatistik", code: "STAT", semester: "2026", creditHours: 3, linkedStudyCourseID: nil, isActive: true, context: context)
        let course = try XCTUnwrap(context.fetch(FetchDescriptor<UniversityCourse>()).first)
        try viewModel.saveAssessment(nil, courseID: course.id, title: "Vize", kind: .midterm, dueDate: .now, maximumPoints: 100, earnedPoints: 75, weightPercent: 40, note: "", context: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<OBSAssessment>()).count, 1)
        XCTAssertThrowsError(try viewModel.saveAssessment(nil, courseID: course.id, title: "Hatalı", kind: .quiz, dueDate: .now, maximumPoints: 100, earnedPoints: 110, weightPercent: 10, note: "", context: context))
        try viewModel.deleteCourse(course, assessments: try context.fetch(FetchDescriptor<OBSAssessment>()), context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<UniversityCourse>()).isEmpty); XCTAssertTrue(try context.fetch(FetchDescriptor<OBSAssessment>()).isEmpty)
    }
}
