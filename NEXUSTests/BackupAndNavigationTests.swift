import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class BackupAndNavigationTests: XCTestCase {
    func testBackupRoundTripAndValidatedImport() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        let viewModel = StudyViewModel()
        try viewModel.saveCourse(nil, name: "Fizik", code: "PHY", instructor: "", location: "", context: source.mainContext)
        let course = try XCTUnwrap(source.mainContext.fetch(FetchDescriptor<Course>()).first)
        try viewModel.saveTask(nil, title: "Laboratuvar", details: "", courseID: course.id, hasDueDate: false, dueDate: .now, status: .planned, priority: .normal, estimatedMinutes: 30, context: source.mainContext)

        let data = try BackupService.encoded(BackupService.export(from: source.mainContext))
        let decoded = try BackupService.decoded(data)
        let destination = try PersistenceController.makeContainer(inMemory: true)
        try BackupService.apply(decoded, mode: .merge, to: destination.mainContext)

        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<Course>()).count, 1)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<StudyTask>()).first?.courseID, course.id)
    }

    func testBackupRejectsDanglingCourseReference() throws {
        let backup = NEXUSBackup(schemaVersion: 1, createdAt: .now, courses: [], tasks: [
            .init(id: UUID(), title: "Görev", details: "", courseID: UUID(), dueDate: nil, status: StudyTaskStatus.planned.rawValue, priority: StudyTaskPriority.normal.rawValue, estimatedMinutes: 30, completedAt: nil, externalCalendarEventIdentifier: nil, createdAt: .now, updatedAt: .now)
        ], goals: [], sessions: [])
        XCTAssertThrowsError(try BackupService.validate(backup)) { XCTAssertTrue($0 is BackupError) }
    }

    func testVersionSixBackupIncludesNotesAndCalendar() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        source.mainContext.insert(NexusNote(title: "Yerel not", body: "İçerik", isPinned: true))
        let start = Date.now
        source.mainContext.insert(CalendarEntry(title: "Hatırlat", startDate: start, endDate: start, kind: .reminder, reminderDate: start.addingTimeInterval(-60)))
        try source.mainContext.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: source.mainContext)))
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertEqual(backup.notes?.count, 1)
        XCTAssertEqual(backup.calendarEntries?.first?.kind, CalendarEntryKind.reminder.rawValue)
    }

    func testVersionSixBackupIncludesAttendanceAndOBS() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        let studyCourse = Course(name: "Matematik")
        source.mainContext.insert(studyCourse)
        source.mainContext.insert(AttendanceRecord(courseID: studyCourse.id, status: .late))
        let universityCourse = UniversityCourse(name: "Matematik I", creditHours: 4, linkedStudyCourseID: studyCourse.id)
        source.mainContext.insert(universityCourse)
        source.mainContext.insert(OBSAssessment(universityCourseID: universityCourse.id, title: "Vize", earnedPoints: 80, weightPercent: 40))
        source.mainContext.insert(GradeScaleBand(letter: "AA", minimumPercent: 85, gradePoints: 4))
        try source.mainContext.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: source.mainContext)))
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertEqual(backup.attendanceRecords?.first?.status, AttendanceStatus.late.rawValue)
        XCTAssertEqual(backup.universityCourses?.first?.creditHours, 4)
        XCTAssertEqual(backup.obsAssessments?.first?.earnedPoints, 80)
        XCTAssertEqual(backup.gradeScaleBands?.first?.letter, "AA")
    }

    func testNavigationContractIsStable() {
        XCTAssertEqual(AppRoute.allCases.count, 8)
        XCTAssertEqual(AppRoute.study.number, 1)
        XCTAssertEqual(AppRoute.organization.number, 8)
        XCTAssertTrue(AppRoute.study.isAvailable)
        XCTAssertEqual(AppRoute.allCases.filter(\.isAvailable), AppRoute.allCases)
    }
}
