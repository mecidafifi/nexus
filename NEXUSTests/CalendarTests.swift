import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class CalendarTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var viewModel: CalendarViewModel!

    override func setUpWithError() throws { container = try PersistenceController.makeContainer(inMemory: true); context = container.mainContext; viewModel = CalendarViewModel() }

    func testCalendarEntryCreateEditDeletePersists() throws {
        let start = Date.now.addingTimeInterval(3600)
        try viewModel.save(nil, title: "Ders", details: "B-12", startDate: start, endDate: start.addingTimeInterval(3600), isAllDay: false, kind: .event, isCompleted: false, hasReminder: true, reminderDate: start.addingTimeInterval(-900), relatedRecordID: nil, courseID: nil, context: context)
        let entry = try XCTUnwrap(context.fetch(FetchDescriptor<CalendarEntry>()).first)
        XCTAssertEqual(entry.kind, .event)
        XCTAssertNotNil(entry.reminderDate)
        try viewModel.save(entry, title: "Ders güncellendi", details: "", startDate: start, endDate: start.addingTimeInterval(7200), isAllDay: false, kind: .task, isCompleted: true, hasReminder: false, reminderDate: start, relatedRecordID: nil, courseID: nil, context: context)
        XCTAssertEqual(entry.title, "Ders güncellendi")
        XCTAssertTrue(entry.isCompleted)
        try viewModel.delete(entry, context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CalendarEntry>()).isEmpty)
    }

    func testCalendarValidationRejectsBadRangeAndLateReminder() {
        XCTAssertThrowsError(try viewModel.save(nil, title: "Etkinlik", details: "", startDate: .now, endDate: .distantPast, isAllDay: false, kind: .event, isCompleted: false, hasReminder: false, reminderDate: .now, relatedRecordID: nil, courseID: nil, context: context))
        let start = Date.now
        XCTAssertThrowsError(try viewModel.save(nil, title: "Etkinlik", details: "", startDate: start, endDate: start.addingTimeInterval(60), isAllDay: false, kind: .reminder, isCompleted: false, hasReminder: true, reminderDate: start.addingTimeInterval(30), relatedRecordID: nil, courseID: nil, context: context))
    }

    func testMonthAndWeekDateCalculations() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!; calendar.firstWeekday = 2
        let components = DateComponents(calendar: calendar, year: 2026, month: 8, day: 27)
        let date = components.date!
        let month = viewModel.monthDays(for: date, calendar: calendar)
        let week = viewModel.weekDays(for: date, calendar: calendar)
        XCTAssertEqual(month.count, 42)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: month[0]), 2)
    }

    func testStudyDueTasksAppearOnMatchingDay() {
        let due = Date.now
        let task = StudyTask(title: "Proje", dueDate: due)
        XCTAssertEqual(viewModel.studyTasks([task], on: due).map(\.id), [task.id])
        XCTAssertTrue(viewModel.studyTasks([task], on: due.addingTimeInterval(86400 * 2)).isEmpty)
    }
}
