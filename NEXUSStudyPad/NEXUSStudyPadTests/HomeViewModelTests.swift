import XCTest
@testable import NEXUSStudyPad

final class HomeViewModelTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    func testTodaySnapshotCountsOnlyDatedTodayTasks() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 10)))
        let todayDone = StudyTask(title: "Bitti", dueDate: now, isCompleted: true)
        let todayOpen = StudyTask(title: "Açık", dueDate: now.addingTimeInterval(3600))
        let undated = StudyTask(title: "Tarihsiz")
        let tomorrow = StudyTask(title: "Yarın", dueDate: now.addingTimeInterval(86400))
        let snapshot = HomeViewModel.snapshot(now: now, calendar: calendar, lectures: [], tasks: [todayDone, todayOpen, undated, tomorrow])
        XCTAssertEqual(snapshot.todayTasks.count, 2)
        XCTAssertEqual(snapshot.completedTasks, 1)
    }

    func testLecturesAreSeparatedAndSorted() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 10)))
        let early = Lecture(courseID: UUID(), title: "Erken", date: now.addingTimeInterval(-3600))
        let late = Lecture(courseID: UUID(), title: "Geç", date: now.addingTimeInterval(3600))
        let future = Lecture(courseID: UUID(), title: "Yarın", date: now.addingTimeInterval(90000))
        let snapshot = HomeViewModel.snapshot(now: now, calendar: calendar, lectures: [late, future, early], tasks: [])
        XCTAssertEqual(snapshot.todayLessons.map(\.title), ["Erken", "Geç"])
        XCTAssertEqual(snapshot.upcomingLessons.map(\.title), ["Yarın"])
    }

    func testImportedWeeklyRulesProjectIntoTodayAndRollingWeek() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 8)))
        let course = Course(name: "Optimizasyon", code: "251141206")
        let saturday = calendar.component(.weekday, from: now)
        let monday = 2
        let saturdayRule = CourseScheduleRule(
            courseID: course.id,
            weekday: saturday,
            startMinutes: 21 * 60,
            durationMinutes: 50,
            effectiveStart: now.addingTimeInterval(-86_400),
            location: "A1"
        )
        let mondayRule = CourseScheduleRule(
            courseID: course.id,
            weekday: monday,
            startMinutes: 10 * 60 + 15,
            durationMinutes: 105,
            effectiveStart: now.addingTimeInterval(-86_400)
        )

        let snapshot = HomeViewModel.snapshot(
            now: now,
            calendar: calendar,
            lectures: [],
            tasks: [],
            rules: [saturdayRule, mondayRule],
            courses: [course]
        )

        XCTAssertEqual(snapshot.todayLessons.map(\.title), ["Optimizasyon"])
        XCTAssertEqual(snapshot.todayLessons.first?.startDate, calendar.date(bySettingHour: 21, minute: 0, second: 0, of: now))
        XCTAssertEqual(snapshot.weekDays.count, 7)
        XCTAssertEqual(snapshot.weekDays.flatMap(\.lessons).count, 2)
        XCTAssertTrue(snapshot.weekDays.flatMap(\.lessons).contains { $0.startDate > now && $0.title == "Optimizasyon" })
    }

    func testProjectionRespectsActiveAndEffectiveDateRange() throws {
        let selected = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 10)))
        let course = Course(name: "Yapay Zeka")
        let weekday = calendar.component(.weekday, from: selected)
        let inactive = CourseScheduleRule(courseID: course.id, weekday: weekday, startMinutes: 600, effectiveStart: selected.addingTimeInterval(-86_400), isActive: false)
        let notStarted = CourseScheduleRule(courseID: course.id, weekday: weekday, startMinutes: 660, effectiveStart: selected.addingTimeInterval(86_400))
        let expired = CourseScheduleRule(courseID: course.id, weekday: weekday, startMinutes: 720, effectiveStart: selected.addingTimeInterval(-172_800), effectiveEnd: selected.addingTimeInterval(-86_400))

        let items = ScheduleOccurrenceProjector.project(
            rules: [inactive, notStarted, expired],
            courses: [course],
            from: selected,
            through: selected,
            calendar: calendar
        )
        XCTAssertTrue(items.isEmpty)
    }

    func testConcreteLectureWinsOverSameCourseAndMinuteProjection() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 8)))
        let start = try XCTUnwrap(calendar.date(bySettingHour: 10, minute: 15, second: 0, of: now))
        let course = Course(name: "Mobil")
        let rule = CourseScheduleRule(
            courseID: course.id,
            weekday: calendar.component(.weekday, from: now),
            startMinutes: 10 * 60 + 15,
            effectiveStart: now.addingTimeInterval(-86_400)
        )
        let lecture = Lecture(courseID: course.id, title: "Gerçek oturum", date: start)
        let snapshot = HomeViewModel.snapshot(now: now, calendar: calendar, lectures: [lecture], tasks: [], rules: [rule], courses: [course])
        XCTAssertEqual(snapshot.todayLessons.count, 1)
        XCTAssertEqual(snapshot.todayLessons.first?.source, .lecture)
    }
}
