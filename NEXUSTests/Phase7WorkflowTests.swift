import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase7WorkflowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ day: Int, month: Int = 8, year: Int = 2026, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testPlannerAvoidsFixedItemsAndProposalOverlap() throws {
        let fixed = [PlannerFixedItem(id: "lesson", title: "Ders", start: date(27, hour: 10), end: date(27, hour: 11))]
        let candidates = [
            PlannerCandidate(source: .studyTask, recordID: UUID(), title: "Kritik ödev", durationMinutes: 60, dueDate: date(27), priorityRank: 4),
            PlannerCandidate(source: .organizationTask, recordID: UUID(), title: "Sunum", durationMinutes: 60, dueDate: date(27), priorityRank: 3)
        ]
        let result = ProposedDailyPlanner.generate(date: date(27), fixed: fixed, candidates: candidates,
                                                   settings: .init(workStartMinutes: 8 * 60, workEndMinutes: 13 * 60, bufferMinutes: 10, defaultTaskDurationMinutes: 45), calendar: calendar)
        XCTAssertEqual(result.placements.count, 2)
        XCTAssertTrue(ProposedDailyPlanner.placementsAreValid(result.placements, fixed: fixed, date: date(27), calendar: calendar))
        XCTAssertFalse(result.placements.contains { $0.start < fixed[0].end && fixed[0].start < $0.end })
    }

    func testPlannerIsDeterministicWithStableTieBreaking() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let candidates = [
            PlannerCandidate(source: .studyTask, recordID: secondID, title: "Aynı", durationMinutes: 30, dueDate: nil, priorityRank: 2),
            PlannerCandidate(source: .studyTask, recordID: firstID, title: "Aynı", durationMinutes: 30, dueDate: nil, priorityRank: 2)
        ]
        let settings = DailyPlannerSettings(workStartMinutes: 480, workEndMinutes: 600, bufferMinutes: 0, defaultTaskDurationMinutes: 30)
        let first = ProposedDailyPlanner.generate(date: date(27), fixed: [], candidates: candidates, settings: settings, calendar: calendar)
        let second = ProposedDailyPlanner.generate(date: date(27), fixed: [], candidates: Array(candidates.reversed()), settings: settings, calendar: calendar)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.placements.first?.candidate.recordID, firstID)
    }

    func testPlannerSurfacesOverloadWithoutPersisting() {
        let candidates = (0..<3).map { PlannerCandidate(source: .studyTask, recordID: UUID(), title: "Görev \($0)", durationMinutes: 60, dueDate: nil, priorityRank: 1) }
        let result = ProposedDailyPlanner.generate(date: date(27), fixed: [], candidates: candidates,
                                                   settings: .init(workStartMinutes: 480, workEndMinutes: 540, bufferMinutes: 0, defaultTaskDurationMinutes: 60), calendar: calendar)
        XCTAssertEqual(result.placements.count, 1)
        XCTAssertEqual(result.unplaced.count, 2)
        XCTAssertTrue(result.hasOverload)
    }

    func testAcceptPersistsOnlyPlacementAndPreservesSourceTask() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let due = date(27, hour: 23)
        let task = StudyTask(title: "Rapor", dueDate: due, status: .planned, priority: .high, estimatedMinutes: 45)
        context.insert(task); try context.save()
        let candidate = PlannerCandidate(source: .studyTask, recordID: task.id, title: task.title, durationMinutes: 45, dueDate: due, priorityRank: 3)
        let proposal = ProposedDailyPlanner.generate(date: date(27), fixed: [], candidates: [candidate],
                                                     settings: .init(workStartMinutes: 480, workEndMinutes: 600, bufferMinutes: 10, defaultTaskDurationMinutes: 45), calendar: calendar)
        try PlannerAcceptanceService.accept(proposal.placements, fixed: [], date: date(27), existing: [], context: context, calendar: calendar, now: date(27, hour: 7))
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedTaskPlacement>()).count, 1)
        XCTAssertEqual(task.dueDate, due)
        XCTAssertEqual(task.status, .planned)
    }

    func testAcceptRejectsEditedOverlapAndWritesNothing() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let task = StudyTask(title: "Çakışan")
        context.insert(task); try context.save()
        let candidate = PlannerCandidate(source: .studyTask, recordID: task.id, title: task.title, durationMinutes: 60, dueDate: nil, priorityRank: 2)
        let placement = ProposedTaskPlacement(candidate: candidate, start: date(27, hour: 10), end: date(27, hour: 11))
        let fixed = [PlannerFixedItem(id: "lesson", title: "Ders", start: date(27, hour: 10, minute: 30), end: date(27, hour: 11, minute: 30))]
        XCTAssertThrowsError(try PlannerAcceptanceService.accept([placement], fixed: fixed, date: date(27), existing: [], context: context, calendar: calendar))
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlannedTaskPlacement>()).isEmpty)
    }

    func testAcceptValidatesEverySourceBeforeMutatingExistingPlacement() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let task = StudyTask(title: "Var olan")
        let existing = PlannedTaskPlacement(source: .studyTask, sourceRecordID: task.id, planDate: date(26), startDate: date(26, hour: 9), endDate: date(26, hour: 10))
        context.insert(task); context.insert(existing); try context.save()
        let valid = ProposedTaskPlacement(candidate: .init(source: .studyTask, recordID: task.id, title: task.title, durationMinutes: 30, dueDate: nil, priorityRank: 2), start: date(27, hour: 8), end: date(27, hour: 8, minute: 30))
        let missing = ProposedTaskPlacement(candidate: .init(source: .organizationTask, recordID: UUID(), title: "Yok", durationMinutes: 30, dueDate: nil, priorityRank: 2), start: date(27, hour: 9), end: date(27, hour: 9, minute: 30))
        XCTAssertThrowsError(try PlannerAcceptanceService.accept([valid, missing], fixed: [], date: date(27), existing: [existing], context: context, calendar: calendar))
        XCTAssertEqual(existing.planDate, date(26))
        XCTAssertEqual(existing.startDate, date(26, hour: 9))
    }

    func testAcceptedPlacementOverlaysTimelineWithoutChangingTaskDeadline() throws {
        let task = StudyTask(title: "Okuma", dueDate: date(28), status: .planned)
        let placement = PlannedTaskPlacement(source: .studyTask, sourceRecordID: task.id, planDate: date(27), startDate: date(27, hour: 14), endDate: date(27, hour: 14, minute: 45))
        let snapshot = DailyPlanAggregator.snapshot(date: date(27), courses: [], rules: [], attendance: [], studyTasks: [task], studySessions: [], plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [], assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], taskPlacements: [placement], calendar: calendar)
        let item = try XCTUnwrap(snapshot.items.first { $0.recordID == task.id })
        XCTAssertEqual(item.start, placement.startDate)
        XCTAssertEqual(item.end, placement.endDate)
        XCTAssertEqual(task.dueDate, date(28))
    }

    func testTurkishLessonParserBuildsEditableDraft() throws {
        let draft = try TurkishQuickEntryParser.parse("Her pazartesi saat 10'da Yapay Zeka var, 20 Aralık'a kadar", referenceDate: date(27, hour: 9), calendar: calendar)
        XCTAssertEqual(draft.kind, .weeklyLesson)
        XCTAssertEqual(draft.title, "Yapay Zeka")
        XCTAssertEqual(draft.weekday, 2)
        XCTAssertEqual(draft.startMinutes, 600)
        XCTAssertEqual(draft.effectiveEnd, date(20, month: 12))
    }

    func testTurkishGymParserProducesReviewableDatesDeterministically() throws {
        let reference = date(24, hour: 8)
        let first = try TurkishQuickEntryParser.parse("Bu hafta saat 17'den sonra üç kez spor", referenceDate: reference, calendar: calendar)
        let second = try TurkishQuickEntryParser.parse("Bu hafta saat 17'den sonra üç kez spor", referenceDate: reference, calendar: calendar)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.kind, .weeklyGym)
        XCTAssertEqual(first.occurrenceDates.count, 3)
        XCTAssertTrue(first.occurrenceDates.allSatisfy { calendar.component(.hour, from: $0) == 17 })
    }

    func testParserRejectsUnsupportedAndInvalidTimeWithoutSideEffects() throws {
        XCTAssertThrowsError(try TurkishQuickEntryParser.parse("Yarın bir şey yap", referenceDate: date(27), calendar: calendar))
        XCTAssertThrowsError(try TurkishQuickEntryParser.parse("Her pazartesi saat 27'da Ders var, 20 Aralık'a kadar", referenceDate: date(27), calendar: calendar))
        let container = try PersistenceController.makeContainer(inMemory: true)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<Course>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<PlannedWorkoutSession>()).isEmpty)
    }

    func testQuickEntryRequiresConfirmThenPersistsOnlyCorrectIndependentModel() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let draft = try TurkishQuickEntryParser.parse("Her pazartesi saat 10'da Yapay Zeka var, 20 Aralık'a kadar", referenceDate: date(27), calendar: calendar)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Course>()).isEmpty)
        let count = try QuickEntryPersistenceService.confirm(draft, courses: [], rules: [], plannedWorkouts: [], context: context, calendar: calendar, now: date(27))
        XCTAssertEqual(count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).first?.name, "Yapay Zeka")
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyScheduleRule>()).first?.weekday, 2)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).isEmpty)
    }

    func testVersionSevenBackupRoundTripsPlacementAndAcceptsVersionSix() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        let task = StudyTask(title: "Planlanan")
        source.mainContext.insert(task)
        source.mainContext.insert(PlannedTaskPlacement(source: .studyTask, sourceRecordID: task.id, planDate: date(27), startDate: date(27, hour: 9), endDate: date(27, hour: 10)))
        try source.mainContext.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: source.mainContext)))
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertEqual(backup.plannedTaskPlacements?.first?.sourceRecordID, task.id)
        let destination = try PersistenceController.makeContainer(inMemory: true)
        try BackupService.apply(backup, mode: .replace, to: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<PlannedTaskPlacement>()).count, 1)

        let legacy = NEXUSBackup(schemaVersion: 6, createdAt: .now, courses: [], tasks: [], goals: [], sessions: [])
        XCTAssertNoThrow(try BackupService.validate(legacy))
        XCTAssertNil(try BackupService.decoded(BackupService.encoded(legacy)).plannedTaskPlacements)
    }

    func testBackupRejectsDanglingPlacementReference() {
        var backup = NEXUSBackup(schemaVersion: 7, createdAt: .now, courses: [], tasks: [], goals: [], sessions: [])
        backup.plannedTaskPlacements = [.init(id: UUID(), source: TaskPlacementSource.studyTask.rawValue, sourceRecordID: UUID(),
                                             planDate: date(27), startDate: date(27, hour: 9), endDate: date(27, hour: 10), createdAt: .now, updatedAt: .now)]
        XCTAssertThrowsError(try BackupService.validate(backup))
    }
}
