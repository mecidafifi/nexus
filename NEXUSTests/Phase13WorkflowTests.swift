import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase13WorkflowTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ day: Int, month: Int = 8, year: Int = 2026, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testEveningAcknowledgementUsesLocalDayAndConfiguredTime() {
        let now = date(28, hour: 20, minute: 30)
        XCTAssertEqual(EveningReviewAcknowledgement.dayKey(for: now, calendar: calendar), "2026-08-28")
        XCTAssertTrue(EveningReviewAcknowledgement.shouldSuggest(lastAcknowledgedDay: "", now: now, endMinutes: 1_200, calendar: calendar))
        XCTAssertFalse(EveningReviewAcknowledgement.shouldSuggest(lastAcknowledgedDay: "2026-08-28", now: now, endMinutes: 1_200, calendar: calendar))
        XCTAssertFalse(EveningReviewAcknowledgement.shouldSuggest(lastAcknowledgedDay: "", now: date(28, hour: 19, minute: 59), endMinutes: 1_200, calendar: calendar))
    }

    func testEveningMetricsUseActualIndependentRecordsAndCancelledIsNotHeld() {
        let courseID = UUID(), ruleID = UUID()
        let first = LessonOccurrence(id: "first", ruleID: ruleID, courseID: courseID, title: "A", subtitle: "", start: date(28, hour: 9), end: date(28, hour: 10))
        let second = LessonOccurrence(id: "second", ruleID: ruleID, courseID: courseID, title: "B", subtitle: "", start: date(28, hour: 11), end: date(28, hour: 12))
        let third = LessonOccurrence(id: "third", ruleID: ruleID, courseID: courseID, title: "C", subtitle: "", start: date(28, hour: 13), end: date(28, hour: 14))
        let completedTask = StudyTask(title: "Bitti", dueDate: date(28, hour: 18), status: .completed)
        let openTask = StudyTask(title: "Açık", dueDate: date(28, hour: 19), status: .planned)
        let calendarTask = CalendarEntry(title: "Takvim", startDate: date(28, hour: 16), endDate: date(28, hour: 17), kind: .task, isCompleted: true)
        let focus = FocusSessionRecord(title: "Odak", source: .studyTask, startedAt: date(28, hour: 15), endedAt: date(28, hour: 15, minute: 25), elapsedSeconds: 1_500, outcome: .stopped)
        let planned = PlannedWorkoutSession(date: date(28, hour: 18), isCompleted: true)
        let logged = WorkoutRecord(date: date(28, hour: 18), title: "Kuvvet")
        let summary = EveningReviewService.make(
            date: date(28), occurrences: [first, second, third],
            attendance: [
                AttendanceRecord(courseID: courseID, date: first.start, status: .present, occurrenceID: first.id),
                AttendanceRecord(courseID: courseID, date: second.start, status: .cancelled, occurrenceID: second.id),
                AttendanceRecord(courseID: courseID, date: third.start, status: .absent, occurrenceID: third.id)
            ],
            studyTasks: [completedTask, openTask], organizationTasks: [], calendarEntries: [calendarTask],
            placements: [], focusSessions: [focus], plannedWorkouts: [planned], completedWorkouts: [logged],
            assessments: [], calendar: calendar
        )
        XCTAssertEqual(summary.scheduledLessons, 3)
        XCTAssertEqual(summary.heldLessons, 2)
        XCTAssertEqual(summary.attendedLessons, 1)
        XCTAssertEqual(summary.cancelledLessons, 1)
        XCTAssertEqual(summary.completedTasks, 2)
        XCTAssertEqual(summary.eligibleTasks, 3)
        XCTAssertEqual(summary.focusSeconds, 1_500)
        XCTAssertEqual(summary.gymPlanned, 1)
        XCTAssertEqual(summary.gymPlannedCompleted, 1)
        XCTAssertEqual(summary.gymLoggedCompleted, 1)
    }

    func testEveningReviewDoesNotCountFutureOrCompletedDeadlineAsOverdue() {
        let overdue = StudyTask(title: "Gecikmiş", dueDate: date(27), status: .planned)
        let future = StudyTask(title: "Gelecek", dueDate: date(29), status: .planned)
        let completed = StudyTask(title: "Tamam", dueDate: date(27), status: .completed)
        let summary = EveningReviewService.make(date: date(28), occurrences: [], attendance: [],
            studyTasks: [overdue, future, completed], organizationTasks: [], calendarEntries: [], placements: [],
            focusSessions: [], plannedWorkouts: [], completedWorkouts: [], assessments: [], calendar: calendar)
        XCTAssertEqual(summary.overdueCount, 1)
        XCTAssertEqual(summary.deadlines.map(\.title), ["Gecikmiş"])
    }

    func testRelativeStudyTaskParserCreatesEditableDraftWithoutWriting() throws {
        let draft = try TurkishQuickEntryParser.parse("Yarın saat 14:30'da Rapor çalışma görevi, 45 dakika", referenceDate: date(28, hour: 9), calendar: calendar)
        XCTAssertEqual(draft.kind, .studyTask)
        XCTAssertEqual(draft.title, "Rapor")
        XCTAssertEqual(draft.effectiveStart, date(29, hour: 14, minute: 30))
        XCTAssertEqual(draft.durationMinutes, 45)
        let container = try PersistenceController.makeContainer(inMemory: true)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<StudyTask>()).isEmpty)
    }

    func testExplicitDateCalendarEventAndThisWeekWeekdayParseDeterministically() throws {
        let explicit = try TurkishQuickEntryParser.parse("12 Eylül 2026 saat 10:15'te Danışman görüşmesi etkinlik, 90 dakika", referenceDate: date(28), calendar: calendar)
        XCTAssertEqual(explicit.kind, .calendarEvent)
        XCTAssertEqual(explicit.effectiveStart, date(12, month: 9, hour: 10, minute: 15))
        XCTAssertEqual(explicit.durationMinutes, 90)

        let weekday = try TurkishQuickEntryParser.parse("Bu hafta cuma saat 17'de Koşu spor, 30 dakika", referenceDate: date(24), calendar: calendar)
        XCTAssertEqual(weekday.kind, .gymSession)
        XCTAssertEqual(calendar.component(.weekday, from: weekday.effectiveStart), 6)
    }

    func testStartEndTimeFormsProduceExactDuration() throws {
        let hyphen = try TurkishQuickEntryParser.parse("Yarın saat 14:00-15:30 Proje görüşmesi etkinlik", referenceDate: date(28), calendar: calendar)
        XCTAssertEqual(hyphen.kind, .calendarEvent)
        XCTAssertEqual(hyphen.startMinutes, 840)
        XCTAssertEqual(hyphen.durationMinutes, 90)
        let suffix = try TurkishQuickEntryParser.parse("Yarın saat 10'dan 11'e Fizik dersi", referenceDate: date(28), calendar: calendar)
        XCTAssertEqual(suffix.kind, .weeklyLesson)
        XCTAssertEqual(suffix.durationMinutes, 60)
        XCTAssertEqual(suffix.effectiveStart, date(29))
        XCTAssertEqual(suffix.effectiveEnd, date(29))
    }

    func testWeekdayLessonCountCreatesExactFiniteRuleDraft() throws {
        let draft = try TurkishQuickEntryParser.parse("Her pazartesi saat 10'da Matematik var, iki kez", referenceDate: date(28), calendar: calendar)
        XCTAssertEqual(draft.kind, .weeklyLesson)
        XCTAssertEqual(draft.weekday, 2)
        XCTAssertEqual(draft.effectiveEnd, date(7, month: 9))
    }

    func testExistingPhaseSevenSentencesRemainSupported() throws {
        XCTAssertEqual(try TurkishQuickEntryParser.parse("Her pazartesi saat 10'da Yapay Zeka var, 20 Aralık'a kadar", referenceDate: date(28), calendar: calendar).kind, .weeklyLesson)
        XCTAssertEqual(try TurkishQuickEntryParser.parse("Bu hafta saat 17'den sonra üç kez spor", referenceDate: date(24, hour: 8), calendar: calendar).occurrenceDates.count, 3)
    }

    func testAmbiguousOrInvalidInputDoesNotWrite() throws {
        XCTAssertThrowsError(try TurkishQuickEntryParser.parse("Bugün ya da yarın saat 10'da Rapor görev", referenceDate: date(28), calendar: calendar))
        XCTAssertThrowsError(try TurkishQuickEntryParser.parse("31 Şubat 2026 saat 10'da Rapor görev", referenceDate: date(28), calendar: calendar))
        let container = try PersistenceController.makeContainer(inMemory: true)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<StudyTask>()).isEmpty)
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<CalendarEntry>()).isEmpty)
    }

    func testConfirmationRoutesEachDraftOnlyToItsOwningModel() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let taskDraft = try TurkishQuickEntryParser.parse("Yarın saat 14'te Rapor çalışma görevi, 45 dakika", referenceDate: date(28), calendar: calendar)
        _ = try QuickEntryPersistenceService.confirm(taskDraft, courses: [], rules: [], plannedWorkouts: [], context: context, calendar: calendar, now: date(28))
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).count, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CalendarEntry>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).isEmpty)

        let eventDraft = try TurkishQuickEntryParser.parse("12 Eylül 2026 saat 10'da Görüşme etkinlik, 30 dakika", referenceDate: date(28), calendar: calendar)
        _ = try QuickEntryPersistenceService.confirm(eventDraft, courses: [], rules: [], plannedWorkouts: [], studyTasks: try context.fetch(FetchDescriptor<StudyTask>()), context: context, calendar: calendar, now: date(28))
        XCTAssertEqual(try context.fetch(FetchDescriptor<CalendarEntry>()).first?.kind, .event)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).count, 1)
    }

    func testDuplicateConfirmationIsRejectedWithoutSecondWrite() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let draft = try TurkishQuickEntryParser.parse("Yarın saat 18'de Kardiyo spor, 30 dakika", referenceDate: date(28), calendar: calendar)
        _ = try QuickEntryPersistenceService.confirm(draft, courses: [], rules: [], plannedWorkouts: [], context: context, calendar: calendar, now: date(28))
        let existing = try context.fetch(FetchDescriptor<PlannedWorkoutSession>())
        XCTAssertThrowsError(try QuickEntryPersistenceService.confirm(draft, courses: [], rules: [], plannedWorkouts: existing, context: context, calendar: calendar, now: date(28)))
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).count, 1)
    }
}
