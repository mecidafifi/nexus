import Foundation
import SwiftData

enum DailyPlanAggregator {
    static func occurrence(for rule: StudyScheduleRule, on date: Date, courses: [Course], calendar: Calendar) -> LessonOccurrence? {
        guard rule.isActive, (1...7).contains(rule.weekday), (0...1_439).contains(rule.startMinutes), rule.durationMinutes > 0 else { return nil }
        let day = calendar.startOfDay(for: date)
        guard ScheduleRuleProjectionPolicy.includes(rule, on: day, calendar: calendar) else { return nil }
        guard calendar.component(.weekday, from: day) == rule.weekday,
              let start = calendar.date(byAdding: .minute, value: rule.startMinutes, to: day),
              let end = calendar.date(byAdding: .minute, value: rule.durationMinutes, to: start) else { return nil }
        let course = courses.first { $0.id == rule.courseID }
        return LessonOccurrence(
            id: LessonOccurrenceKey.make(ruleID: rule.id, scheduledStart: start), ruleID: rule.id, courseID: rule.courseID,
            title: course?.name ?? String(localized: "dailyPlan.unknownCourse"),
            subtitle: ScheduleRulePresentationPolicy.subtitle(for: rule, course: course), start: start, end: end
        )
    }

    static func occurrences(rules: [StudyScheduleRule], on date: Date, courses: [Course], calendar: Calendar = .current) -> [LessonOccurrence] {
        rules.compactMap { occurrence(for: $0, on: date, courses: courses, calendar: calendar) }.sorted { $0.start < $1.start }
    }

    static func snapshot(
        date: Date, courses: [Course], rules: [StudyScheduleRule], attendance: [AttendanceRecord],
        studyTasks: [StudyTask], studySessions: [StudySession], plannedWorkouts: [PlannedWorkoutSession],
        workoutPlans: [WorkoutPlan], completedWorkouts: [WorkoutRecord], calendarEntries: [CalendarEntry],
        assessments: [OBSAssessment], universityCourses: [UniversityCourse], debts: [DebtRecord],
        recurringTransactions: [RecurringTransaction], notes: [NexusNote], organizationProjects: [ProjectRecord] = [], organizationTasks: [OrganizationTask] = [], taskPlacements: [PlannedTaskPlacement] = [], focusSessions: [FocusSessionRecord] = [], calendar: Calendar = .current
    ) -> DailyPlanSnapshot {
        let day = calendar.startOfDay(for: date)
        let lessons = occurrences(rules: rules, on: day, courses: courses, calendar: calendar)
        var items: [DailyPlanItem] = []

        for lesson in lessons {
            let record = attendance.first { $0.occurrenceID == lesson.id }
            let attended = record != nil
            let status = record.map { String(localized: String.LocalizationValue($0.status.titleKey)) } ?? String(localized: "dailyPlan.attendance.unmarked")
            items.append(item(id: lesson.id, source: .attendance, kind: .lesson, recordID: record?.id,
                              title: lesson.title, subtitle: [lesson.subtitle, status].filter { !$0.isEmpty }.joined(separator: " · "),
                              start: lesson.start, end: lesson.end, completed: attended, actionable: true, important: true,
                              occurrenceID: lesson.id, courseID: lesson.courseID))
        }
        for task in studyTasks where task.dueDate.map({ calendar.isDate($0, inSameDayAs: day) }) == true || placement(.studyTask, task.id, on: day, values: taskPlacements, calendar: calendar) != nil {
            let accepted = placement(.studyTask, task.id, on: day, values: taskPlacements, calendar: calendar)
            items.append(item(id: "study-task:\(task.id)", source: .study, kind: .studyTask, recordID: task.id,
                              title: task.title, subtitle: courseName(task.courseID, courses: courses), start: accepted?.startDate ?? task.dueDate,
                              end: accepted?.endDate,
                              completed: task.status == .completed, actionable: task.status != .cancelled,
                              important: task.priority == .high || task.priority == .critical, courseID: task.courseID))
        }
        for session in studySessions where calendar.isDate(session.startedAt, inSameDayAs: day) {
            items.append(item(id: "study-session:\(session.id)", source: .study, kind: .studySession, recordID: session.id,
                              title: String(localized: "dailyPlan.studySession"), subtitle: courseName(session.courseID, courses: courses),
                              start: session.startedAt, end: calendar.date(byAdding: .minute, value: session.durationMinutes, to: session.startedAt),
                              completed: true, courseID: session.courseID))
        }
        for focus in focusSessions where calendar.isDate(focus.startedAt, inSameDayAs: day) {
            let source: DailyPlanSource = switch focus.source {
            case .studyTask, .studyContext: .study
            case .organizationTask: .organization
            case .calendarTask: .calendar
            }
            items.append(item(id: "focus-session:\(focus.id)", source: source, kind: .focusSession, recordID: focus.id,
                              title: focus.title, subtitle: String(format: String(localized: "focus.historySeconds"), focus.elapsedSeconds),
                              start: focus.startedAt, end: focus.endedAt, completed: true, courseID: focus.courseID))
        }
        for workout in plannedWorkouts where calendar.isDate(workout.date, inSameDayAs: day) {
            items.append(item(id: "planned-workout:\(workout.id)", source: .gym, kind: .gym, recordID: workout.id,
                              title: GymSessionDisplayPolicy.title(for: workout, plans: workoutPlans), subtitle: workout.note, start: workout.date,
                              end: nil,
                              completed: workout.isCompleted, actionable: true))
        }
        for workout in completedWorkouts where calendar.isDate(workout.date, inSameDayAs: day) {
            items.append(item(id: "completed-workout:\(workout.id)", source: .gym, kind: .gym, recordID: workout.id,
                              title: workout.title, subtitle: String(format: String(localized: "dailyPlan.minutesFormat"), workout.durationMinutes),
                              start: workout.date, end: calendar.date(byAdding: .minute, value: workout.durationMinutes, to: workout.date), completed: true))
        }
        for entry in calendarEntries where intersects(entry.startDate, entry.endDate, day: day, calendar: calendar) || placement(.calendarTask, entry.id, on: day, values: taskPlacements, calendar: calendar) != nil {
            let accepted = placement(.calendarTask, entry.id, on: day, values: taskPlacements, calendar: calendar)
            items.append(item(id: "calendar:\(entry.id)", source: .calendar, kind: .calendar, recordID: entry.id,
                              title: entry.title, subtitle: entry.details, start: accepted?.startDate ?? (entry.isAllDay ? nil : entry.startDate),
                              end: accepted?.endDate ?? (entry.isAllDay ? nil : entry.endDate), completed: entry.isCompleted,
                              actionable: entry.kind != .event, important: entry.kind == .reminder, courseID: entry.courseID))
        }
        for assessment in assessments where calendar.isDate(assessment.dueDate, inSameDayAs: day) {
            let course = universityCourses.first { $0.id == assessment.universityCourseID }
            items.append(item(id: "assessment:\(assessment.id)", source: .obs, kind: .assessment, recordID: assessment.id,
                              title: assessment.title, subtitle: course?.name ?? "", start: assessment.dueDate,
                              completed: assessment.earnedPoints != nil, actionable: true, important: assessment.earnedPoints == nil,
                              courseID: course?.linkedStudyCourseID))
        }
        for debt in debts where debt.status == .outstanding && debt.dueDate.map({ calendar.isDate($0, inSameDayAs: day) }) == true {
            let detail = debt.direction == .owedByUser ? String(localized: "dailyPlan.debt.owed") : String(localized: "dailyPlan.debt.receivable")
            items.append(item(id: "debt:\(debt.id)", source: .finance, kind: .financeDue, recordID: debt.id,
                              title: debt.counterparty, subtitle: detail, start: debt.dueDate, actionable: true, important: true))
        }
        for recurring in recurringTransactions where recurring.isActive && calendar.isDate(recurring.nextDate, inSameDayAs: day) {
            items.append(item(id: "recurring:\(recurring.id)", source: .finance, kind: .financeDue, recordID: recurring.id,
                              title: recurring.title, subtitle: String(localized: "dailyPlan.recurringTransaction"), start: recurring.nextDate))
        }
        // NexusNote currently has no due/reminder field. Undated and pinned
        // notes therefore stay in Notes instead of being fabricated as daily
        // events. A future dated-note entity can opt in here when it exists.
        _ = notes
        for task in organizationTasks where (task.dueDate.map({ calendar.isDate($0, inSameDayAs: day) }) == true || placement(.organizationTask, task.id, on: day, values: taskPlacements, calendar: calendar) != nil) && task.status != .cancelled {
            let project = organizationProjects.first { $0.id == task.projectID }
            let accepted = placement(.organizationTask, task.id, on: day, values: taskPlacements, calendar: calendar)
            items.append(item(id: "organization-task:\(task.id)", source: .organization, kind: .organizationTask, recordID: task.id,
                              title: task.title, subtitle: project?.title ?? "", start: accepted?.startDate ?? task.dueDate,
                              end: accepted?.endDate,
                              completed: task.status == .completed, actionable: true,
                              important: task.priority == .high || task.priority == .critical))
        }

        items.sort {
            switch ($0.start, $1.start) {
            case let (left?, right?): left == right ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : left < right
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        }
        let actionable = items.filter(\.isActionable)
        let cancelledOccurrenceIDs = Set(attendance.filter { $0.status == .cancelled }.map(\.occurrenceID))
        let blockingLessons = lessons.filter { !cancelledOccurrenceIDs.contains($0.id) }
        return DailyPlanSnapshot(
            date: day, items: items, lessons: lessons,
            freeBlocks: freeTimeBlocks(day: day, lessons: blockingLessons, calendarEntries: calendarEntries, taskPlacements: taskPlacements, calendar: calendar),
            completedCount: actionable.filter(\.isCompleted).count, actionableCount: actionable.count, organizationAvailable: true
        )
    }

    static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [calendar.startOfDay(for: date)] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    static func monthDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let firstWeek = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: firstWeek.start) }
    }

    private static func freeTimeBlocks(day: Date, lessons: [LessonOccurrence], calendarEntries: [CalendarEntry], taskPlacements: [PlannedTaskPlacement], calendar: Calendar) -> [DailyPlanItem] {
        guard let workStart = calendar.date(byAdding: .hour, value: 8, to: day),
              let workEnd = calendar.date(byAdding: .hour, value: 20, to: day) else { return [] }
        var intervals = lessons.map { DateInterval(start: $0.start, end: $0.end) }
        intervals += calendarEntries.filter { !$0.isAllDay && intersects($0.startDate, $0.endDate, day: day, calendar: calendar) }
            .compactMap {
                let start = max($0.startDate, workStart)
                let end = min($0.endDate, workEnd)
                return end > start ? DateInterval(start: start, end: end) : nil
            }
        intervals += taskPlacements.filter { calendar.isDate($0.planDate, inSameDayAs: day) && $0.endDate > $0.startDate }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }
        let bounded = intervals.filter { $0.end > workStart && $0.start < workEnd }.sorted { $0.start < $1.start }
        var cursor = workStart
        var output: [DailyPlanItem] = []
        for interval in bounded {
            if interval.start.timeIntervalSince(cursor) >= 1_800 { output.append(freeItem(start: cursor, end: interval.start)) }
            cursor = max(cursor, interval.end)
        }
        if workEnd.timeIntervalSince(cursor) >= 1_800 { output.append(freeItem(start: cursor, end: workEnd)) }
        return output
    }

    private static func freeItem(start: Date, end: Date) -> DailyPlanItem {
        item(id: "free:\(Int64(start.timeIntervalSince1970))", source: .calendar, kind: .freeTime,
             title: String(localized: "dailyPlan.freeTime"), start: start, end: end)
    }

    private static func item(id: String, source: DailyPlanSource, kind: DailyPlanItemKind, recordID: UUID? = nil,
                             title: String, subtitle: String = "", start: Date? = nil, end: Date? = nil,
                             completed: Bool = false, actionable: Bool = false, important: Bool = false,
                             occurrenceID: String? = nil, courseID: UUID? = nil) -> DailyPlanItem {
        DailyPlanItem(id: id, source: source, kind: kind, recordID: recordID, title: title, subtitle: subtitle,
                      start: start, end: end, isCompleted: completed, isActionable: actionable, isImportant: important,
                      occurrenceID: occurrenceID, courseID: courseID)
    }

    private static func courseName(_ id: UUID?, courses: [Course]) -> String {
        guard let id else { return "" }
        return courses.first { $0.id == id }?.name ?? String(localized: "dailyPlan.unknownCourse")
    }

    private static func placement(_ source: TaskPlacementSource, _ recordID: UUID, on day: Date,
                                  values: [PlannedTaskPlacement], calendar: Calendar) -> PlannedTaskPlacement? {
        values.first { $0.source == source && $0.sourceRecordID == recordID && calendar.isDate($0.planDate, inSameDayAs: day) }
    }

    private static func intersects(_ start: Date, _ end: Date, day: Date, calendar: Calendar) -> Bool {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return false }
        return start < nextDay && end >= day
    }
}

@MainActor
enum DailyPlanAttendanceService {
    @discardableResult
    static func mark(occurrence: LessonOccurrence, status: AttendanceStatus, records: [AttendanceRecord], context: ModelContext, now: Date = .now) throws -> AttendanceRecord {
        if let existing = records.first(where: { $0.occurrenceID == occurrence.id }) {
            existing.status = status
            existing.date = occurrence.start
            existing.courseID = occurrence.courseID
            existing.scheduleRuleID = occurrence.ruleID
            existing.updatedAt = now
            try context.save()
            return existing
        }
        let record = AttendanceRecord(courseID: occurrence.courseID, date: occurrence.start, status: status,
                                      occurrenceID: occurrence.id, scheduleRuleID: occurrence.ruleID, createdAt: now, updatedAt: now)
        context.insert(record)
        try context.save()
        return record
    }
}
