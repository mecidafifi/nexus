import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class AttendanceTests: XCTestCase {
    func testPercentageSemanticsExcludeExcusedAndCountLateAsAttended() throws {
        let viewModel = AttendanceViewModel(); let course = UUID()
        let records = [AttendanceRecord(courseID: course, status: .present), AttendanceRecord(courseID: course, status: .late), AttendanceRecord(courseID: course, status: .absent), AttendanceRecord(courseID: course, status: .excused)]
        let summary = viewModel.summary(records, courseID: course)
        XCTAssertEqual(summary.eligible, 3); XCTAssertEqual(summary.attended, 2); XCTAssertEqual(summary.excused, 1)
        XCTAssertEqual(try XCTUnwrap(summary.percentage), 66.666666, accuracy: 0.001)
    }

    func testNoEligibleSessionsHasNoPercentageAndNoWarning() {
        let viewModel = AttendanceViewModel(); let summary = viewModel.summary([AttendanceRecord(status: .excused)])
        XCTAssertNil(summary.percentage); XCTAssertFalse(viewModel.isBelowThreshold(summary, threshold: 75))
    }

    func testThresholdUsesStrictlyBelowSemantics() {
        let viewModel = AttendanceViewModel(); let summary = AttendanceSummary(present: 3, absent: 1, late: 0, excused: 0)
        XCTAssertFalse(viewModel.isBelowThreshold(summary, threshold: 75)); XCTAssertTrue(viewModel.isBelowThreshold(summary, threshold: 80))
    }

    func testAttendanceCRUDAndCourseValidation() throws {
        let container = try PersistenceController.makeContainer(inMemory: true); let context = container.mainContext; let viewModel = AttendanceViewModel(); let courseID = UUID()
        try viewModel.save(nil, courseID: courseID, date: .now, status: .late, note: "10 dakika", context: context)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<AttendanceRecord>()).first)
        XCTAssertEqual(record.status, .late); XCTAssertTrue(record.wasPresent)
        try viewModel.save(record, courseID: courseID, date: .now, status: .absent, note: "", context: context)
        XCTAssertEqual(record.status, .absent); XCTAssertFalse(record.wasPresent)
        try viewModel.delete(record, context: context); XCTAssertTrue(try context.fetch(FetchDescriptor<AttendanceRecord>()).isEmpty)
        XCTAssertThrowsError(try viewModel.save(nil, courseID: nil, date: .now, status: .present, note: "", context: context))
    }
}
