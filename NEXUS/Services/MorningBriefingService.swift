import Foundation

struct MorningBriefingDeadline: Identifiable, Equatable {
    let id: String
    let title: String
    let date: Date
}

struct MorningBriefingSummary: Equatable {
    let heldLessonCount: Int
    let cancelledLessonCount: Int
    let flexibleTaskCount: Int
    let imminentDeadlines: [MorningBriefingDeadline]
    let freeTimeSeconds: Int
    let focusSecondsToday: Int

    var isEmpty: Bool {
        heldLessonCount == 0 && cancelledLessonCount == 0 && flexibleTaskCount == 0 &&
        imminentDeadlines.isEmpty && focusSecondsToday == 0
    }
}

enum MorningBriefingAcknowledgement {
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func shouldPresent(lastAcknowledgedDay: String, on date: Date, calendar: Calendar = .current) -> Bool {
        lastAcknowledgedDay != dayKey(for: date, calendar: calendar)
    }
}

enum MorningBriefingService {
    static func make(
        date: Date, snapshot: DailyPlanSnapshot, attendance: [AttendanceRecord],
        studyTasks: [StudyTask], organizationTasks: [OrganizationTask],
        calendarEntries: [CalendarEntry], assessments: [OBSAssessment],
        focusSessions: [FocusSessionRecord], calendar: Calendar = .current
    ) -> MorningBriefingSummary {
        let day = calendar.startOfDay(for: date)
        let cancelledOccurrences = Set(attendance.filter { $0.status == .cancelled }.map(\.occurrenceID))
        let heldLessons = snapshot.lessons.filter { !cancelledOccurrences.contains($0.id) }.count
        let cancelledLessons = snapshot.lessons.filter { cancelledOccurrences.contains($0.id) }.count
        let flexibleKinds: Set<DailyPlanItemKind> = [.studyTask, .organizationTask, .calendar]
        let flexibleTasks = snapshot.items.filter {
            flexibleKinds.contains($0.kind) && $0.isActionable && !$0.isCompleted && $0.kind != .lesson
        }.count

        let deadlineEnd = calendar.date(byAdding: .day, value: 4, to: day) ?? day
        var deadlines: [MorningBriefingDeadline] = []
        func imminent(_ value: Date?) -> Bool { value.map { $0 >= day && $0 < deadlineEnd } ?? false }
        deadlines += studyTasks.filter { $0.status != .completed && $0.status != .cancelled && imminent($0.dueDate) }
            .compactMap { task in task.dueDate.map { .init(id: "study:\(task.id)", title: task.title, date: $0) } }
        deadlines += organizationTasks.filter { $0.status != .completed && $0.status != .cancelled && imminent($0.dueDate) }
            .compactMap { task in task.dueDate.map { .init(id: "organization:\(task.id)", title: task.title, date: $0) } }
        deadlines += calendarEntries.filter { $0.kind != .event && !$0.isCompleted && imminent($0.startDate) }
            .map { .init(id: "calendar:\($0.id)", title: $0.title, date: $0.startDate) }
        deadlines += assessments.filter { $0.earnedPoints == nil && imminent($0.dueDate) }
            .map { .init(id: "assessment:\($0.id)", title: $0.title, date: $0.dueDate) }
        deadlines.sort { $0.date == $1.date ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : $0.date < $1.date }

        let freeSeconds = snapshot.freeBlocks.reduce(0) { total, block in
            guard let start = block.start, let end = block.end else { return total }
            return total + max(Int(end.timeIntervalSince(start)), 0)
        }
        let focusSeconds = focusSessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + max($1.elapsedSeconds, 0) }
        return .init(heldLessonCount: heldLessons, cancelledLessonCount: cancelledLessons,
                     flexibleTaskCount: flexibleTasks, imminentDeadlines: deadlines,
                     freeTimeSeconds: freeSeconds, focusSecondsToday: focusSeconds)
    }
}
