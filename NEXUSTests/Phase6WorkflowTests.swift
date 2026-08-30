import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase6WorkflowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return value
    }

    private func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    func testSemesterSetupPersistsCourseAndRecurringRules() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = try SemesterScheduleService.save(course: nil, name: "Algoritmalar", code: "CS201", instructor: "Dr. A", room: "B-12", semesterStart: date(1), semesterEnd: date(31), allowedAbsences: 4, examDate: date(28), weekdays: [3, 5], startMinutes: 570, durationMinutes: 75, existingRules: [], context: context)
        let rules = try context.fetch(FetchDescriptor<StudyScheduleRule>())
        XCTAssertEqual(course.allowedAbsenceCount, 4)
        XCTAssertEqual(course.examDate, date(28))
        XCTAssertEqual(Set(rules.map(\.weekday)), Set([3, 5]))
        XCTAssertTrue(rules.allSatisfy { $0.effectiveStart == date(1) && $0.effectiveEnd == date(31) && $0.startMinutes == 570 })
    }

    func testSemesterUpdateDisablesRemovedWeekdayWithoutDeletingHistoryRule() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Fizik")
        let monday = StudyScheduleRule(courseID: course.id, weekday: 2, startMinutes: 540, effectiveStart: date(1))
        let friday = StudyScheduleRule(courseID: course.id, weekday: 6, startMinutes: 540, effectiveStart: date(1))
        context.insert(course); context.insert(monday); context.insert(friday); try context.save()
        _ = try SemesterScheduleService.save(course: course, name: course.name, code: "", instructor: "", room: "", semesterStart: date(1), semesterEnd: date(31), allowedAbsences: 3, examDate: nil, weekdays: [2], startMinutes: 600, durationMinutes: 50, existingRules: [monday, friday], context: context)
        XCTAssertTrue(monday.isActive)
        XCTAssertFalse(friday.isActive)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyScheduleRule>()).count, 2)
    }

    func testCancelledAttendanceDoesNotCountAsHeldOrAbsentAndOnlineCountsAttended() throws {
        let viewModel = AttendanceViewModel()
        let courseID = UUID()
        let summary = viewModel.summary([
            AttendanceRecord(courseID: courseID, status: .present),
            AttendanceRecord(courseID: courseID, status: .absent),
            AttendanceRecord(courseID: courseID, status: .cancelled),
            AttendanceRecord(courseID: courseID, status: .online),
            AttendanceRecord(courseID: courseID, status: .excused)
        ], courseID: courseID)
        XCTAssertEqual(summary.held, 3)
        XCTAssertEqual(summary.attended, 2)
        XCTAssertEqual(summary.absent, 1)
        XCTAssertEqual(summary.cancelled, 1)
        XCTAssertEqual(viewModel.remainingAbsences(summary, allowed: 3), 2)
        XCTAssertEqual(try XCTUnwrap(summary.percentage), 66.666666, accuracy: 0.001)
    }

    func testOccurrenceStateUpdatesOnlySelectedDateAndPreservesSeries() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Kimya")
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 600, effectiveStart: date(1))
        context.insert(course); context.insert(rule); try context.save()
        let first = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: date(27), courses: [course], calendar: calendar))
        let record = try DailyPlanAttendanceService.mark(occurrence: first, status: .cancelled, records: [], context: context)
        _ = try DailyPlanAttendanceService.mark(occurrence: first, status: .online, records: [record], context: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AttendanceRecord>()).count, 1)
        XCTAssertEqual(record.status, .online)
        XCTAssertEqual(rule.weekday, 5)
        XCTAssertTrue(rule.isActive)
    }

    func testEndOfDayReviewNeverReschedulesWithoutExplicitChoice() throws {
        let overdue = StudyTask(title: "Rapor", dueDate: date(20), status: .planned)
        let items = OverdueReviewService.items(studyTasks: [overdue], organizationTasks: [], reviewDate: date(27), calendar: calendar)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(overdue.dueDate, date(20))
        XCTAssertNil(overdue.overdueReviewedAt)
    }

    func testEndOfDayChoicesMoveKeepAndCancelDeterministically() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let project = ProjectRecord(title: "P")
        let organization = OrganizationTask(projectID: project.id, title: "Teslim", dueDate: date(20), status: .active)
        let study = StudyTask(title: "Ödev", dueDate: date(20), status: .planned)
        context.insert(project); context.insert(organization); context.insert(study); try context.save()
        let items = OverdueReviewService.items(studyTasks: [study], organizationTasks: [organization], reviewDate: date(27), calendar: calendar)
        let studyItem = try XCTUnwrap(items.first { $0.source == .study })
        let organizationItem = try XCTUnwrap(items.first { $0.source == .organization })
        try OverdueReviewService.apply(.tomorrow, to: studyItem, anotherDate: nil, studyTasks: [study], organizationTasks: [organization], reviewDate: date(27), calendar: calendar, context: context)
        try OverdueReviewService.apply(.cancel, to: organizationItem, anotherDate: nil, studyTasks: [study], organizationTasks: [organization], reviewDate: date(27), calendar: calendar, context: context)
        XCTAssertEqual(study.dueDate, date(28))
        XCTAssertEqual(organization.status, .cancelled)
        XCTAssertTrue(OverdueReviewService.items(studyTasks: [study], organizationTasks: [organization], reviewDate: date(27), calendar: calendar).isEmpty)
    }

    func testConflictDetectionAndNextAvailableSlot() throws {
        let existing = [ScheduleSlot(id: UUID(), weekday: 2, startMinutes: 540, durationMinutes: 60)]
        let proposed = ScheduleSlot(id: UUID(), weekday: 2, startMinutes: 570, durationMinutes: 60)
        XCTAssertEqual(ScheduleConflictService.conflicts(proposed, with: existing).count, 1)
        XCTAssertEqual(ScheduleConflictService.nextAvailableStart(for: proposed, existing: existing), 600)
        XCTAssertTrue(ScheduleConflictService.conflicts(ScheduleSlot(id: UUID(), weekday: 3, startMinutes: 570, durationMinutes: 60), with: existing).isEmpty)
    }

    func testVersionFiveBackupRemainsImportableWithoutPhaseSixFields() throws {
        let legacy = NEXUSBackup(schemaVersion: 5, createdAt: .now, courses: [], tasks: [], goals: [], sessions: [])
        let decoded = try BackupService.decoded(BackupService.encoded(legacy))
        XCTAssertEqual(decoded.schemaVersion, 5)
        XCTAssertNil(decoded.organizationProjects)
        XCTAssertNil(decoded.organizationTasks)
    }
}
