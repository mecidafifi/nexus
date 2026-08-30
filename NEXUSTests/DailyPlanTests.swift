import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class DailyPlanTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ day: Int, month: Int = 8, year: Int = 2026, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testRecurringLessonResolvesOnlyMatchingEffectiveDayAndStableKey() throws {
        let course = Course(name: "Algoritmalar", location: "B-12")
        let thursday = date(27)
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 9 * 60 + 30, durationMinutes: 75, effectiveStart: date(20), effectiveEnd: date(30))
        let first = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: thursday, courses: [course], calendar: calendar))
        let again = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: thursday.addingTimeInterval(3_600), courses: [course], calendar: calendar))
        XCTAssertEqual(first.id, again.id)
        XCTAssertEqual(first.start, date(27, hour: 9, minute: 30))
        XCTAssertEqual(first.end, date(27, hour: 10, minute: 45))
        XCTAssertNil(DailyPlanAggregator.occurrence(for: rule, on: date(28), courses: [course], calendar: calendar))
        XCTAssertNil(DailyPlanAggregator.occurrence(for: rule, on: date(3), courses: [course], calendar: calendar))
    }

    func testProvisionalPreviousYearTimetableProjectsExactWeekAndOneKnownConflict() throws {
        let courseValues: [(String, String)] = [
            ("Siber Güvenliğe Giriş", "251141204"), ("Optimizasyon", "251141206"),
            ("Mobil Uygulama Geliştirme", "251131202"), ("Yapay Zeka", "251141103"),
            ("Robotik", "251141202"), ("Bilimsel Araştırma Yöntemleri", "251141101"),
            ("Fizik I", "251111101"),
        ]
        let courses = courseValues.map { Course(name: $0.0, code: $0.1) }
        let byCode = Dictionary(uniqueKeysWithValues: courses.map { ($0.code, $0) })
        let importedAt = date(29)
        let specs: [(String, Int, Int, Int, String?)] = [
            ("251141204", 2, 615, 105, "T"), ("251141204", 3, 495, 105, "T/U"),
            ("251141206", 2, 780, 105, "T"), ("251141206", 4, 495, 105, "T/U"),
            ("251131202", 3, 780, 105, "T"), ("251131202", 4, 615, 105, "T/U"),
            ("251141103", 4, 615, 105, "T/U"), ("251141103", 5, 615, 105, "U"),
            ("251141202", 3, 615, 105, nil), ("251141202", 4, 780, 105, nil),
            ("251141101", 5, 780, 105, nil), ("251111101", 6, 495, 165, nil),
        ]
        let rules = try specs.map { spec in
            let (code, weekday, start, duration, modality) = spec
            let course = try XCTUnwrap(byCode[code])
            let metadata = ProvisionalScheduleMetadata(
                modality: modality,
                sourceCourseName: code == "251141202" ? "Robotik Kodlama" : nil,
                sourceCourseCode: code == "251141202" ? "251111106" : nil
            )
            return StudyScheduleRule(courseID: course.id, weekday: weekday, startMinutes: start,
                                     durationMinutes: duration, effectiveStart: importedAt,
                                     effectiveEnd: nil, locationOverride: metadata.encodedValue)
        }

        XCTAssertEqual(rules.count, 12)
        XCTAssertEqual(Set(rules.map(\.courseID)).count, 7)
        XCTAssertTrue(rules.allSatisfy { $0.effectiveEnd == nil })
        let weeks = [date(17), date(24), date(31)].map { selected in
            DailyPlanAggregator.weekDates(containing: selected, calendar: calendar).map {
                DailyPlanAggregator.occurrences(rules: rules, on: $0, courses: courses, calendar: calendar)
            }
        }
        for occurrences in weeks {
            XCTAssertEqual(occurrences.map(\.count), [2, 3, 4, 2, 1, 0, 0])
            XCTAssertEqual(occurrences[0].map(\.title), ["Siber Güvenliğe Giriş", "Optimizasyon"])
            XCTAssertEqual(occurrences[1].map(\.title), ["Siber Güvenliğe Giriş", "Robotik", "Mobil Uygulama Geliştirme"])
            XCTAssertEqual(occurrences[2].map(\.title), ["Optimizasyon", "Mobil Uygulama Geliştirme", "Yapay Zeka", "Robotik"])
            XCTAssertTrue(try XCTUnwrap(occurrences[1].first { $0.title == "Robotik" }).subtitle.contains("Robotik Kodlama 251111106"))
            XCTAssertTrue(occurrences.flatMap { $0 }.allSatisfy { $0.subtitle.contains("doğrulanmayı bekliyor") })
        }
        XCTAssertTrue(DailyPlanAggregator.occurrences(rules: rules, on: date(30), courses: courses, calendar: calendar).isEmpty)

        let slots = rules.map { ScheduleSlot(id: $0.id, weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes) }
        let conflicts = ScheduleConflictService.overlappingPairs(slots)
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts.first?.0.weekday, 4)
        XCTAssertEqual(conflicts.first?.0.startMinutes, 615)
        XCTAssertEqual(conflicts.first?.1.startMinutes, 615)
    }

    func testViewingProvisionalPastAndFutureOccurrencesDoesNotMutatePersistentModels() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Siber Güvenliğe Giriş", code: "251141204")
        let metadata = ProvisionalScheduleMetadata(modality: "T", sourceCourseName: nil, sourceCourseCode: nil)
        let rule = StudyScheduleRule(courseID: course.id, weekday: 2, startMinutes: 615,
                                     durationMinutes: 105, effectiveStart: date(29), effectiveEnd: nil,
                                     locationOverride: metadata.encodedValue)
        context.insert(course)
        context.insert(rule)
        try context.save()

        let storedStart = rule.effectiveStart
        let storedUpdatedAt = rule.updatedAt
        for selected in [date(17), date(24), date(31), date(7, month: 9)] {
            let occurrence = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: selected, courses: [course], calendar: calendar))
            XCTAssertEqual(calendar.component(.hour, from: occurrence.start), 10)
            XCTAssertEqual(calendar.component(.minute, from: occurrence.start), 15)
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<AttendanceRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyScheduleRule>()).count, 1)
        XCTAssertEqual(rule.effectiveStart, storedStart)
        XCTAssertEqual(rule.updatedAt, storedUpdatedAt)
        XCTAssertTrue(rule.isActive)
    }

    func testDailyAggregationKeepsSourceLinksAndCalculatesProgress() throws {
        let day = date(27)
        let course = Course(name: "Matematik")
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 600, effectiveStart: date(1))
        let lesson = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: day, courses: [course], calendar: calendar))
        let attendance = AttendanceRecord(courseID: course.id, date: lesson.start, status: .present, occurrenceID: lesson.id, scheduleRuleID: rule.id)
        let task = StudyTask(title: "Problem seti", courseID: course.id, dueDate: day, status: .completed, priority: .high)
        let calendarTask = CalendarEntry(title: "Başvuru", startDate: day, endDate: day.addingTimeInterval(900), kind: .task)
        let university = UniversityCourse(name: "Matematik I", linkedStudyCourseID: course.id)
        let assessment = OBSAssessment(universityCourseID: university.id, title: "Vize", dueDate: day, earnedPoints: nil)
        let debt = DebtRecord(counterparty: "Kırtasiye", amountMinorUnits: 5000, dueDate: day)
        let note = NexusNote(title: "Formüller", isPinned: true)
        let workout = PlannedWorkoutSession(date: day, isCompleted: true)

        let snapshot = DailyPlanAggregator.snapshot(date: day, courses: [course], rules: [rule], attendance: [attendance],
            studyTasks: [task], studySessions: [], plannedWorkouts: [workout], workoutPlans: [], completedWorkouts: [],
            calendarEntries: [calendarTask], assessments: [assessment], universityCourses: [university], debts: [debt],
            recurringTransactions: [], notes: [note], calendar: calendar)

        XCTAssertEqual(Set(snapshot.items.map(\.source)), Set([.attendance, .study, .gym, .calendar, .obs, .finance]))
        XCTAssertEqual(snapshot.actionableCount, 6)
        XCTAssertEqual(snapshot.completedCount, 3)
        XCTAssertEqual(snapshot.progress, 0.5, accuracy: 0.0001)
        XCTAssertTrue(snapshot.organizationAvailable)
        XCTAssertEqual(snapshot.items.first(where: { $0.kind == .studyTask })?.courseID, course.id)
    }

    func testPlannedGymSessionsUseSpecificRoutineTitlesAsExactTimePoints() throws {
        let expected: [(stored: String, title: String, day: Int)] = [
            ("Haftalık Antrenman Planı — 21:00 · Pazartesi · Üst Vücut A", "Üst Vücut A", 31),
            ("Haftalık Antrenman Planı — 21:00 · Salı · Bacak A", "Bacak A", 1),
            ("Haftalık Antrenman Planı — 21:00 · Çarşamba · Kardiyo ve Karın", "Kardiyo ve Karın", 2),
            ("Haftalık Antrenman Planı — 21:00 · Perşembe · Üst Vücut B", "Üst Vücut B", 3),
            ("Haftalık Antrenman Planı — 21:00 · Cumartesi · Bacak B Hafif + Kardiyo", "Bacak B Hafif + Kardiyo", 5),
        ]

        for value in expected {
            let month = value.day == 31 ? 8 : 9
            let sessionDate = date(value.day, month: month, hour: 21)
            let plan = WorkoutPlan(name: value.stored)
            let session = PlannedWorkoutSession(planID: plan.id, date: sessionDate, isCompleted: false, note: "Haftalık niyet")
            let snapshot = DailyPlanAggregator.snapshot(
                date: sessionDate, courses: [], rules: [], attendance: [], studyTasks: [], studySessions: [],
                plannedWorkouts: [session], workoutPlans: [plan], completedWorkouts: [], calendarEntries: [],
                assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar
            )
            let item = try XCTUnwrap(snapshot.items.first(where: { $0.kind == .gym }))
            XCTAssertEqual(item.title, value.title)
            XCTAssertEqual(item.start, sessionDate)
            XCTAssertNil(item.end)
            XCTAssertTrue(DailyPlanTimelinePolicy.isPointInTime(item))
            XCTAssertTrue(DailyPlanTimelinePolicy.timedItems(from: snapshot).contains(where: { $0.id == item.id }))
            XCTAssertEqual(calendar.component(.hour, from: try XCTUnwrap(item.start)), 21)
            XCTAssertEqual(item.recordID, session.id)
        }
    }

    func testCurrentAndFollowingWeekContainOnlyTheirActualGymSessions() {
        let values: [(String, Date)] = [
            ("Bacak B Hafif + Kardiyo", date(29, hour: 21)),
            ("Üst Vücut A", date(31, hour: 21)),
            ("Bacak A", date(1, month: 9, hour: 21)),
            ("Kardiyo ve Karın", date(2, month: 9, hour: 21)),
            ("Üst Vücut B", date(3, month: 9, hour: 21)),
        ]
        let plans = values.map { WorkoutPlan(name: $0.0) }
        let sessions = zip(plans, values).map { plan, value in
            PlannedWorkoutSession(planID: plan.id, date: value.1)
        }
        func titles(in week: Date) -> [String] {
            DailyPlanAggregator.weekDates(containing: week, calendar: calendar).flatMap { day in
                DailyPlanAggregator.snapshot(
                    date: day, courses: [], rules: [], attendance: [], studyTasks: [], studySessions: [],
                    plannedWorkouts: sessions, workoutPlans: plans, completedWorkouts: [], calendarEntries: [],
                    assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar
                ).items.filter { $0.kind == .gym }.map(\.title)
            }
        }
        XCTAssertEqual(titles(in: date(29)), ["Bacak B Hafif + Kardiyo"])
        XCTAssertEqual(titles(in: date(31)), ["Üst Vücut A", "Bacak A", "Kardiyo ve Karın", "Üst Vücut B"])
    }

    func testGymSessionDisplayPolicyPreservesCustomNamesAndUsesUnlinkedSessionTitle() {
        let custom = WorkoutPlan(name: "Kuvvet ve Mobilite")
        let linked = PlannedWorkoutSession(planID: custom.id, date: date(31, hour: 21), note: "Not")
        XCTAssertEqual(GymSessionDisplayPolicy.title(for: linked, plans: [custom]), "Kuvvet ve Mobilite")

        let unlinked = PlannedWorkoutSession(date: date(31, hour: 21), note: "Akşam Kardiyosu")
        XCTAssertEqual(GymSessionDisplayPolicy.title(for: unlinked, plans: []), "Akşam Kardiyosu")
    }

    func testAttendanceActionUpdatesOnlyExactOccurrence() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let course = Course(name: "Fizik")
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 540, effectiveStart: date(1))
        context.insert(course); context.insert(rule); try context.save()
        let first = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: date(27), courses: [course], calendar: calendar))
        let future = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: date(3, month: 9), courses: [course], calendar: calendar))
        XCTAssertNotEqual(first.id, future.id)

        let created = try DailyPlanAttendanceService.mark(occurrence: first, status: .present, records: [], context: context, now: date(27, hour: 12))
        _ = try DailyPlanAttendanceService.mark(occurrence: first, status: .absent, records: [created], context: context, now: date(27, hour: 13))
        let records = try context.fetch(FetchDescriptor<AttendanceRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.occurrenceID, first.id)
        XCTAssertEqual(records.first?.status, .absent)
        XCTAssertFalse(records.contains { $0.occurrenceID == future.id })
        XCTAssertEqual(rule.weekday, 5)
        XCTAssertEqual(rule.startMinutes, 540)
    }

    func testWeekMonthBoundariesAndFreeBlocks() {
        let dates = DailyPlanAggregator.weekDates(containing: date(27), calendar: calendar)
        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(calendar.component(.weekday, from: dates[0]), 2)
        let month = DailyPlanAggregator.monthDates(containing: date(27), calendar: calendar)
        XCTAssertEqual(month.count, 42)
        XCTAssertEqual(calendar.component(.weekday, from: month[0]), 2)

        let course = Course(name: "Ders")
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 600, durationMinutes: 60, effectiveStart: date(1))
        let snapshot = DailyPlanAggregator.snapshot(date: date(27), courses: [course], rules: [rule], attendance: [], studyTasks: [], studySessions: [], plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [], assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar)
        XCTAssertEqual(snapshot.freeBlocks.count, 2)
        XCTAssertEqual(snapshot.freeBlocks[0].start, date(27, hour: 8))
        XCTAssertEqual(snapshot.freeBlocks[0].end, date(27, hour: 10))
    }

    func testVersionSixBackupRoundTripsScheduleAndOccurrenceLink() throws {
        let source = try PersistenceController.makeContainer(inMemory: true)
        let course = Course(name: "Kimya")
        let rule = StudyScheduleRule(courseID: course.id, weekday: 5, startMinutes: 660, effectiveStart: date(1))
        let occurrence = try XCTUnwrap(DailyPlanAggregator.occurrence(for: rule, on: date(27), courses: [course], calendar: calendar))
        source.mainContext.insert(course); source.mainContext.insert(rule)
        source.mainContext.insert(AttendanceRecord(courseID: course.id, date: occurrence.start, status: .late, occurrenceID: occurrence.id, scheduleRuleID: rule.id))
        try source.mainContext.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: source.mainContext)))
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertEqual(backup.studyScheduleRules?.first?.id, rule.id)
        XCTAssertEqual(backup.attendanceRecords?.first?.occurrenceID, occurrence.id)

        let destination = try PersistenceController.makeContainer(inMemory: true)
        try BackupService.apply(backup, mode: .replace, to: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<StudyScheduleRule>()).count, 1)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<AttendanceRecord>()).first?.scheduleRuleID, rule.id)
    }

    func testLegacyVersionFourWithoutPlanningFieldsRemainsImportable() throws {
        let legacy = NEXUSBackup(schemaVersion: 4, createdAt: .now, courses: [], tasks: [], goals: [], sessions: [])
        let decoded = try BackupService.decoded(BackupService.encoded(legacy))
        XCTAssertEqual(decoded.schemaVersion, 4)
        XCTAssertNil(decoded.studyScheduleRules)
        try BackupService.validate(decoded)
    }

    func testBackupRejectsInvalidScheduleRange() {
        let courseID = UUID()
        var backup = NEXUSBackup(schemaVersion: 5, createdAt: .now,
            courses: [.init(id: courseID, name: "Ders", code: "", instructor: "", location: "", colorHex: "#78FF9A", createdAt: .now, updatedAt: .now)],
            tasks: [], goals: [], sessions: [])
        backup.studyScheduleRules = [.init(id: UUID(), courseID: courseID, weekday: 8, startMinutes: 1_500, durationMinutes: 0,
                                                  effectiveStart: .now, effectiveEnd: nil, locationOverride: "", isActive: true, createdAt: .now, updatedAt: .now)]
        XCTAssertThrowsError(try BackupService.validate(backup))
    }

    func testPhaseTwelveResponsiveWidthClassesAreStableAtBoundaries() {
        XCTAssertEqual(DailyPlanDashboardLayoutPolicy.widthClass(for: 600), .compact)
        XCTAssertEqual(DailyPlanDashboardLayoutPolicy.widthClass(for: 779), .compact)
        XCTAssertEqual(DailyPlanDashboardLayoutPolicy.widthClass(for: 780), .medium)
        XCTAssertEqual(DailyPlanDashboardLayoutPolicy.widthClass(for: 1_119), .medium)
        XCTAssertEqual(DailyPlanDashboardLayoutPolicy.widthClass(for: 1_120), .wide)
    }

    func testTimelineAlwaysCoversWholeLocalDayAndIncludesLatePointItem() {
        let early = dailyItem(id: "early", kind: .calendar, start: date(27, hour: 6, minute: 30), end: date(27, hour: 7, minute: 15))
        let late = dailyItem(id: "late", kind: .gym, start: date(27, hour: 21), end: nil)
        let bounds = DailyPlanTimelinePolicy.bounds(for: [late, early], on: date(27), calendar: calendar)
        XCTAssertEqual(bounds.startMinutes, 0)
        XCTAssertEqual(bounds.endMinutes, 24 * 60)
        XCTAssertEqual(bounds.durationMinutes, 24 * 60)
        let snapshot = DailyPlanSnapshot(date: date(27), items: [late], lessons: [], freeBlocks: [], completedCount: 0, actionableCount: 1, organizationAvailable: true)
        XCTAssertEqual(DailyPlanTimelinePolicy.timedItems(from: snapshot).map(\.id), ["late"])
        XCTAssertTrue(DailyPlanTimelinePolicy.isPointInTime(late))
    }

    func testUndatedPinnedNotesRemainOutsideEveryDailyPlanDate() {
        let note = NexusNote(title: "Beslenme hedefleri", isPinned: true)
        let snapshot = DailyPlanAggregator.snapshot(date: date(29), courses: [], rules: [], attendance: [], studyTasks: [],
            studySessions: [], plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [],
            assessments: [], universityCourses: [], debts: [], recurringTransactions: [], notes: [note], calendar: calendar)
        XCTAssertFalse(snapshot.items.contains { $0.source == .notes || $0.kind == .pinnedNote })
    }

    func testRollingUpcomingSevenDaysStartsTodayAndExcludesPastCalendarWeekCards() throws {
        let dates = DailyPlanPresentationPolicy.upcomingDates(starting: date(29), calendar: calendar)
        XCTAssertEqual(dates, [date(29), date(30), date(31), date(1, month: 9), date(2, month: 9), date(3, month: 9), date(4, month: 9)])
        XCTAssertFalse(dates.contains(date(24)))
        XCTAssertFalse(dates.contains(date(28)))
        XCTAssertEqual(DailyPlanPresentationPolicy.defaultSelectedDate(now: date(29, hour: 18), calendar: calendar), date(29))
        XCTAssertNotEqual(DailyPlanPresentationPolicy.defaultSelectedDate(now: date(29), calendar: calendar), date(24))
        XCTAssertEqual(DailyPlanPresentationPolicy.defaultMode, .week)

        let courses = [
            Course(name: "Siber Güvenliğe Giriş", code: "251141204"),
            Course(name: "Optimizasyon", code: "251141206"),
            Course(name: "Mobil Uygulama Geliştirme", code: "251131202"),
            Course(name: "Yapay Zeka", code: "251141103"),
            Course(name: "Robotik", code: "251141202"),
            Course(name: "Bilimsel Araştırma Yöntemleri", code: "251141101"),
            Course(name: "Fizik I", code: "251111101"),
        ]
        let byCode = Dictionary(uniqueKeysWithValues: courses.map { ($0.code, $0) })
        let specs: [(String, Int, Int, Int)] = [
            ("251141204", 2, 615, 105), ("251141204", 3, 495, 105),
            ("251141206", 2, 780, 105), ("251141206", 4, 495, 105),
            ("251131202", 3, 780, 105), ("251131202", 4, 615, 105),
            ("251141103", 4, 615, 105), ("251141103", 5, 615, 105),
            ("251141202", 3, 615, 105), ("251141202", 4, 780, 105),
            ("251141101", 5, 780, 105), ("251111101", 6, 495, 165),
        ]
        let rules = try specs.map { spec in
            let (code, weekday, start, duration) = spec
            let course = try XCTUnwrap(byCode[code])
            return StudyScheduleRule(courseID: course.id, weekday: weekday, startMinutes: start,
                                     durationMinutes: duration, effectiveStart: date(29),
                                     locationOverride: ProvisionalScheduleMetadata(modality: nil, sourceCourseName: nil, sourceCourseCode: nil).encodedValue)
        }
        let gym = PlannedWorkoutSession(date: date(29, hour: 21))
        let snapshots = dates.map { day in
            DailyPlanAggregator.snapshot(date: day, courses: courses, rules: rules, attendance: [], studyTasks: [], studySessions: [],
                plannedWorkouts: [gym], workoutPlans: [], completedWorkouts: [], calendarEntries: [], assessments: [],
                universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar)
        }
        XCTAssertEqual(snapshots.map { $0.lessons.count }, [0, 0, 2, 3, 4, 2, 1])
        XCTAssertEqual(snapshots[0].items.filter { $0.kind == .gym }.count, 1)
        XCTAssertTrue(snapshots[1].items.isEmpty)

        let previous = DailyPlanPresentationPolicy.upcomingDates(starting: date(22), calendar: calendar)
        XCTAssertEqual(previous.first, date(22))
        XCTAssertEqual(previous.last, date(28))
        XCTAssertEqual(DailyPlanAggregator.occurrences(rules: rules, on: date(24), courses: courses, calendar: calendar).map(\.title),
                       ["Siber Güvenliğe Giriş", "Optimizasyon"])
    }

    func testRollingRangeSurfacesOnlyActuallyDatedFutureModuleItems() {
        let dates = DailyPlanPresentationPolicy.upcomingDates(starting: date(29), calendar: calendar)
        let study = StudyTask(title: "Gelecek ödev", dueDate: date(1, month: 9, hour: 17))
        let project = ProjectRecord(title: "Dönem projesi")
        let organization = OrganizationTask(projectID: project.id, title: "Gelecek organizasyon görevi", dueDate: date(2, month: 9, hour: 12))
        let reminder = CalendarEntry(title: "Gelecek hatırlatıcı", startDate: date(3, month: 9, hour: 9),
                                     endDate: date(3, month: 9, hour: 9, minute: 15), kind: .reminder)
        let university = UniversityCourse(name: "Ders")
        let assessment = OBSAssessment(universityCourseID: university.id, title: "Gelecek sınav", dueDate: date(4, month: 9, hour: 10))
        let debt = DebtRecord(counterparty: "Gelecek ödeme", amountMinorUnits: 1_000, dueDate: date(4, month: 9, hour: 18))
        let undatedNote = NexusNote(title: "Tarihsiz sabit not", isPinned: true)

        let snapshots = dates.map { day in
            DailyPlanAggregator.snapshot(date: day, courses: [], rules: [], attendance: [], studyTasks: [study], studySessions: [],
                plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [reminder], assessments: [assessment],
                universityCourses: [university], debts: [debt], recurringTransactions: [], notes: [undatedNote],
                organizationProjects: [project], organizationTasks: [organization], calendar: calendar)
        }

        XCTAssertTrue(snapshots[3].items.contains { $0.kind == .studyTask && $0.title == study.title })
        XCTAssertTrue(snapshots[4].items.contains { $0.kind == .organizationTask && $0.title == organization.title })
        XCTAssertTrue(snapshots[5].items.contains { $0.kind == .calendar && $0.title == reminder.title })
        XCTAssertTrue(snapshots[6].items.contains { $0.kind == .assessment && $0.title == assessment.title })
        XCTAssertTrue(snapshots[6].items.contains { $0.kind == .financeDue && $0.title == debt.counterparty })
        XCTAssertTrue(snapshots.allSatisfy { snapshot in
            !snapshot.items.contains { $0.source == .notes || $0.kind == .pinnedNote }
        })
    }

    func testPhaseTwelveTimelineLanesAvoidOverlapDeterministically() {
        let first = dailyItem(id: "a", kind: .lesson, start: date(27, hour: 9), end: date(27, hour: 11))
        let second = dailyItem(id: "b", kind: .calendar, start: date(27, hour: 10), end: date(27, hour: 12))
        let third = dailyItem(id: "c", kind: .gym, start: date(27, hour: 12), end: date(27, hour: 13))
        let free = dailyItem(id: "free", kind: .freeTime, start: date(27, hour: 8), end: date(27, hour: 9))
        let lanes = DailyPlanTimelinePolicy.lanes(for: [third, free, second, first])
        XCTAssertEqual(lanes, [
            .init(itemID: "a", lane: 0),
            .init(itemID: "b", lane: 1),
            .init(itemID: "c", lane: 0),
        ])
        XCTAssertEqual(DailyPlanTimelinePolicy.lanes(for: [second, first, third]), lanes)
    }

    func testPhaseTwelveEmptyAndTaskReadModelsStayHonest() {
        let empty = DailyPlanAggregator.snapshot(
            date: date(27), courses: [], rules: [], attendance: [], studyTasks: [], studySessions: [],
            plannedWorkouts: [], workoutPlans: [], completedWorkouts: [], calendarEntries: [], assessments: [],
            universityCourses: [], debts: [], recurringTransactions: [], notes: [], calendar: calendar
        )
        let emptyTimeline = DailyPlanTimelinePolicy.timedItems(from: empty)
        XCTAssertFalse(DailyPlanTimelinePolicy.hasScheduledContent(emptyTimeline))
        XCTAssertEqual(emptyTimeline.count, 1)
        XCTAssertEqual(emptyTimeline.first?.kind.rawValue, DailyPlanItemKind.freeTime.rawValue)
        XCTAssertTrue(DailyPlanTimelinePolicy.selectedDayTasks(from: empty).isEmpty)

        let pending = dailyItem(id: "pending", kind: .studyTask, start: date(27, hour: 14), end: date(27, hour: 15), completed: false, actionable: true)
        let completed = dailyItem(id: "completed", kind: .organizationTask, start: date(27, hour: 10), end: date(27, hour: 11), completed: true, actionable: true)
        let lesson = dailyItem(id: "lesson", kind: .lesson, start: date(27, hour: 9), end: date(27, hour: 10), actionable: true)
        let populated = DailyPlanSnapshot(date: date(27), items: [completed, lesson, pending], lessons: [], freeBlocks: [], completedCount: 1, actionableCount: 3, organizationAvailable: true)
        XCTAssertTrue(DailyPlanTimelinePolicy.hasScheduledContent(DailyPlanTimelinePolicy.timedItems(from: populated)))
        XCTAssertEqual(DailyPlanTimelinePolicy.selectedDayTasks(from: populated).map(\.id), ["pending", "completed"])
    }

    func testPhaseTwelveOneTaskProgressUsesOnlyCompletableRowsAndFormatsExactRatio() {
        let tasks = (1...15).map { index in
            dailyItem(
                id: "task-\(index)",
                kind: .studyTask,
                start: date(27, hour: 12),
                end: date(27, hour: 13),
                completed: index <= 6,
                actionable: true
            )
        }
        let lesson = dailyItem(id: "lesson", kind: .lesson, start: date(27, hour: 9), end: date(27, hour: 10), completed: true, actionable: true)
        let assessment = dailyItem(id: "assessment", kind: .assessment, start: date(27, hour: 15), end: date(27, hour: 16), actionable: true)

        let sixOfFifteen = DailyPlanTaskProgressPolicy.progress(from: tasks + [lesson, assessment])
        XCTAssertEqual(sixOfFifteen.completed, 6)
        XCTAssertEqual(sixOfFifteen.total, 15)
        XCTAssertEqual(sixOfFifteen.fraction, 0.4, accuracy: 0.0001)
        XCTAssertEqual(sixOfFifteen.countText, "6/15")
        XCTAssertEqual(sixOfFifteen.percentageText, "40%")
        XCTAssertEqual(sixOfFifteen.asciiBar(width: 10), "[████······]")

        var toggled = tasks
        toggled[6] = dailyItem(id: "task-7", kind: .studyTask, start: date(27, hour: 12), end: date(27, hour: 13), completed: true, actionable: true)
        let sevenOfFifteen = DailyPlanTaskProgressPolicy.progress(from: toggled)
        XCTAssertEqual(sevenOfFifteen.countText, "7/15")
        XCTAssertEqual(sevenOfFifteen.percentageText, "46.7%")
    }

    func testPhaseTwelveOneDirectStudyTaskTogglePersistsAndTogglesBackWithoutEditor() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let task = StudyTask(title: "TEST — Günlük görev 07", dueDate: date(27), status: .planned)
        context.insert(task)
        try context.save()
        let item = DailyPlanItem(
            id: "study-task-\(task.id.uuidString)", source: .study, kind: .studyTask, recordID: task.id,
            title: task.title, subtitle: "", start: task.dueDate, end: task.dueDate?.addingTimeInterval(3_600),
            isCompleted: false, isActionable: true, isImportant: false, occurrenceID: nil, courseID: task.courseID
        )

        let completed = try DailyPlanTaskCompletionService.toggle(
            item: item, studyTasks: [task], organizationTasks: [], calendarEntries: [],
            plannedWorkouts: [], context: context, now: date(27, hour: 12)
        )
        XCTAssertTrue(completed)
        XCTAssertEqual(task.status, .completed)
        XCTAssertNotNil(task.completedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).first?.status, .completed)

        let completedItem = DailyPlanItem(
            id: item.id, source: item.source, kind: item.kind, recordID: item.recordID,
            title: item.title, subtitle: item.subtitle, start: item.start, end: item.end,
            isCompleted: true, isActionable: true, isImportant: item.isImportant,
            occurrenceID: item.occurrenceID, courseID: item.courseID
        )
        let restored = try DailyPlanTaskCompletionService.toggle(
            item: completedItem, studyTasks: [task], organizationTasks: [], calendarEntries: [],
            plannedWorkouts: [], context: context, now: date(27, hour: 13)
        )
        XCTAssertFalse(restored)
        XCTAssertEqual(task.status, .planned)
        XCTAssertNil(task.completedAt)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).first?.status, .planned)
    }

    private func dailyItem(
        id: String,
        kind: DailyPlanItemKind,
        start: Date? = nil,
        end: Date? = nil,
        completed: Bool = false,
        actionable: Bool = false,
        important: Bool = false
    ) -> DailyPlanItem {
        DailyPlanItem(
            id: id, source: kind == .lesson ? .attendance : .calendar, kind: kind, recordID: UUID(),
            title: id, subtitle: "", start: start, end: end, isCompleted: completed,
            isActionable: actionable, isImportant: important, occurrenceID: nil, courseID: nil
        )
    }
}
