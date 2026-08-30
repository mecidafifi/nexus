import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase8WorkflowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    func testMorningBriefingAcknowledgementIsOncePerLocalDay() {
        let first = date(27, hour: 8)
        let key = MorningBriefingAcknowledgement.dayKey(for: first, calendar: calendar)
        XCTAssertEqual(key, "2026-08-27")
        XCTAssertTrue(MorningBriefingAcknowledgement.shouldPresent(lastAcknowledgedDay: "", on: first, calendar: calendar))
        XCTAssertFalse(MorningBriefingAcknowledgement.shouldPresent(lastAcknowledgedDay: key, on: date(27, hour: 23), calendar: calendar))
        XCTAssertTrue(MorningBriefingAcknowledgement.shouldPresent(lastAcknowledgedDay: key, on: date(28, hour: 0), calendar: calendar))
    }

    func testBriefingCountsRealTasksAndCancelledLessonIsNotHeldOrBlockingFreeTime() throws {
        let course = Course(name: "Yapay Zeka")
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 600, durationMinutes: 60, effectiveStart: date(1))
        let lesson = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: date(27), courses: [course], calendar: calendar))
        let cancelled = AttendanceRecord(courseID: course.id, date: lesson.start, status: .cancelled, occurrenceID: lesson.id, scheduleRuleID: rule.id)
        let study = StudyTask(title: "Ödev", dueDate: date(27, hour: 18), status: .planned)
        let entry = CalendarEntry(title: "Başvuru", startDate: date(27), endDate: date(27), isAllDay: true, kind: .task)
        let snapshot = DailyPlanAggregator.snapshot(date: date(27), courses: [course], rules: [rule], attendance: [cancelled],
            studyTasks: [study], studySessions: [], plannedWorkouts: [], workoutPlans: [], completedWorkouts: [],
            calendarEntries: [entry], assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar)
        let summary = MorningBriefingService.make(date: date(27), snapshot: snapshot, attendance: [cancelled],
            studyTasks: [study], organizationTasks: [], calendarEntries: [entry], assessments: [], focusSessions: [], calendar: calendar)
        XCTAssertEqual(summary.heldLessonCount, 0)
        XCTAssertEqual(summary.cancelledLessonCount, 1)
        XCTAssertEqual(summary.flexibleTaskCount, 2)
        XCTAssertEqual(summary.imminentDeadlines.count, 2)
        XCTAssertEqual(summary.freeTimeSeconds, 12 * 60 * 60)
    }

    func testBriefingFreeTimeNeverBecomesNegativeWithOverlaps() {
        let first = CalendarEntry(title: "A", startDate: date(27, hour: 7), endDate: date(27, hour: 21))
        let second = CalendarEntry(title: "B", startDate: date(27, hour: 10), endDate: date(27, hour: 11))
        let snapshot = DailyPlanAggregator.snapshot(date: date(27), courses: [], rules: [], attendance: [], studyTasks: [],
            studySessions: [], plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [first, second],
            assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar)
        let summary = MorningBriefingService.make(date: date(27), snapshot: snapshot, attendance: [], studyTasks: [],
            organizationTasks: [], calendarEntries: [first, second], assessments: [], focusSessions: [], calendar: calendar)
        XCTAssertEqual(summary.freeTimeSeconds, 0)
    }

    func testFocusClockUsesMonotonicTimeAcrossPauseResumeWithoutDoubleCounting() {
        let request = FocusRequest(source: .studyContext, title: "Çalışma", plannedDurationSeconds: 600)
        var state = FocusClockState(request: request, startedAt: date(27), uptime: 100)
        XCTAssertEqual(state.elapsedSeconds(at: 110), 10)
        state.pause(at: 110)
        state.pause(at: 150)
        XCTAssertEqual(state.elapsedSeconds(at: 200), 10)
        state.resume(at: 200)
        state.resume(at: 205)
        XCTAssertEqual(state.elapsedSeconds(at: 215), 25)
    }

    func testFocusControllerSurvivesViewRefreshCallsAndClassifiesShortSessions() {
        let controller = FocusSessionController()
        XCTAssertTrue(controller.begin(.init(source: .studyContext, title: "Tekrar"), now: date(27), uptime: 50))
        XCTAssertFalse(controller.begin(.init(source: .studyContext, title: "İkinci"), now: date(27), uptime: 51))
        XCTAssertEqual(controller.readiness(uptime: 50), .noElapsedTime)
        XCTAssertEqual(controller.readiness(uptime: 55), .shortSession)
        XCTAssertEqual(controller.elapsedSeconds(uptime: 65), 15)
        XCTAssertEqual(controller.elapsedSeconds(uptime: 65), 15)
        XCTAssertEqual(controller.readiness(uptime: 65), .ready)
    }

    func testStopPersistsElapsedWithoutCompletingTask() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let task = StudyTask(title: "Makale", status: .planned)
        context.insert(task); try context.save()
        let request = FocusRequest(source: .studyTask, sourceRecordID: task.id, title: task.title, plannedDurationSeconds: 1_800)
        let snapshot = FocusFinishSnapshot(request: request, startedAt: date(27, hour: 9), endedAt: date(27, hour: 9, minute: 5), elapsedSeconds: 300, outcome: .stopped)
        try FocusPersistenceService.save(snapshot, studyTasks: [task], organizationTasks: [], calendarEntries: [], context: context)
        XCTAssertEqual(task.status, .planned)
        let record = try XCTUnwrap(context.fetch(FetchDescriptor<FocusSessionRecord>()).first)
        XCTAssertEqual(record.elapsedSeconds, 300)
        XCTAssertEqual(record.outcome, .stopped)
    }

    func testCompletePersistsAndUpdatesOnlyIntendedTask() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let intended = StudyTask(title: "Tamamla", status: .planned)
        let unrelated = StudyTask(title: "Dokunma", status: .planned)
        context.insert(intended); context.insert(unrelated); try context.save()
        let request = FocusRequest(source: .studyTask, sourceRecordID: intended.id, title: intended.title)
        let snapshot = FocusFinishSnapshot(request: request, startedAt: date(27, hour: 9), endedAt: date(27, hour: 9, minute: 1), elapsedSeconds: 60, outcome: .completed)
        try FocusPersistenceService.save(snapshot, studyTasks: [intended, unrelated], organizationTasks: [], calendarEntries: [], context: context)
        XCTAssertEqual(intended.status, .completed)
        XCTAssertNotNil(intended.completedAt)
        XCTAssertEqual(unrelated.status, .planned)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FocusSessionRecord>()).count, 1)
    }

    func testCompletionGuardWritesNothingForMissingSource() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let request = FocusRequest(source: .organizationTask, sourceRecordID: UUID(), title: "Silinen")
        let snapshot = FocusFinishSnapshot(request: request, startedAt: date(27), endedAt: date(27, minute: 1), elapsedSeconds: 60, outcome: .completed)
        XCTAssertThrowsError(try FocusPersistenceService.save(snapshot, studyTasks: [], organizationTasks: [], calendarEntries: [], context: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<FocusSessionRecord>()).isEmpty)
    }

    func testFocusHistoryContributesOnlyStudySourcesToStudyMinutes() throws {
        let study = FocusSessionRecord(title: "Ders", source: .studyTask, startedAt: date(27), endedAt: date(27, minute: 2), elapsedSeconds: 125, outcome: .stopped)
        let organization = FocusSessionRecord(title: "Proje", source: .organizationTask, sourceRecordID: UUID(), startedAt: date(27), endedAt: date(27, minute: 3), elapsedSeconds: 180, outcome: .stopped)
        let viewModel = StudyViewModel()
        XCTAssertEqual(viewModel.totalFocusMinutes([study, organization]), 2)
        let snapshot = DailyPlanAggregator.snapshot(date: date(27), courses: [], rules: [], attendance: [], studyTasks: [], studySessions: [], plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [], assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], focusSessions: [study], calendar: calendar)
        XCTAssertEqual(snapshot.items.first { $0.kind == .focusSession }?.recordID, study.id)
    }

    func testVersionEightBackupRoundTripsFocusAndAcceptsVersionSeven() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        source.mainContext.insert(FocusSessionRecord(title: "Odak", source: .studyContext,
            startedAt: date(27), endedAt: date(27, minute: 2), elapsedSeconds: 90,
            plannedDurationSeconds: 1_500, outcome: .stopped))
        try source.mainContext.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: source.mainContext)))
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertEqual(backup.focusSessions?.first?.elapsedSeconds, 90)
        let destination = try PersistenceController.makeContainer(inMemory: true)
        try BackupService.apply(backup, mode: .replace, to: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<FocusSessionRecord>()).count, 1)

        let legacy = NEXUSBackup(schemaVersion: 7, createdAt: date(27), courses: [], tasks: [], goals: [], sessions: [])
        XCTAssertNoThrow(try BackupService.validate(legacy))
        XCTAssertNil(try BackupService.decoded(BackupService.encoded(legacy)).focusSessions)
    }

    func testBackupRejectsInvalidFocusRecord() {
        var backup = NEXUSBackup(schemaVersion: 8, createdAt: date(27), courses: [], tasks: [], goals: [], sessions: [])
        backup.focusSessions = [.init(id: UUID(), title: "", source: FocusSource.studyTask.rawValue,
            sourceRecordID: nil, courseID: nil, startedAt: date(27), endedAt: date(27), elapsedSeconds: 0,
            plannedDurationSeconds: -1, outcome: "unknown", createdAt: date(27))]
        XCTAssertThrowsError(try BackupService.validate(backup))
    }
}
