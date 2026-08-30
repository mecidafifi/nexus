import Foundation

struct HomeLessonItem: Identifiable, Equatable {
    enum Source: Equatable {
        case lecture
        case scheduleRule
    }

    let id: String
    let source: Source
    let courseID: UUID?
    let title: String
    let detail: String
    let startDate: Date
    let endDate: Date?
    let location: String
    let status: String
}

struct HomeDaySnapshot: Identifiable {
    var id: Date { date }
    let date: Date
    let lessons: [HomeLessonItem]
    let tasks: [StudyTask]
}

struct HomeSnapshot {
    let todayLessons: [HomeLessonItem]
    let upcomingLessons: [HomeLessonItem]
    let todayTasks: [StudyTask]
    let completedTasks: Int
    let weekDays: [HomeDaySnapshot]
}

enum ScheduleOccurrenceProjector {
    static func project(
        rules: [CourseScheduleRule],
        courses: [Course],
        from startDate: Date,
        through endDate: Date,
        calendar: Calendar = .current
    ) -> [HomeLessonItem] {
        let coursesByID = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0) })
        let firstDay = calendar.startOfDay(for: min(startDate, endDate))
        let lastDay = calendar.startOfDay(for: max(startDate, endDate))
        var day = firstDay
        var result: [HomeLessonItem] = []

        while day <= lastDay {
            let weekday = calendar.component(.weekday, from: day)
            for rule in rules where rule.isActive && rule.weekday == weekday {
                let effectiveStartDay = calendar.startOfDay(for: rule.effectiveStart)
                guard day >= effectiveStartDay else { continue }
                if let effectiveEnd = rule.effectiveEnd,
                   day > calendar.startOfDay(for: effectiveEnd) {
                    continue
                }
                guard let start = calendar.date(byAdding: .minute, value: rule.startMinutes, to: day) else { continue }
                let end = calendar.date(byAdding: .minute, value: rule.durationMinutes, to: start)
                let course = coursesByID[rule.courseID]
                result.append(
                    HomeLessonItem(
                        id: "schedule-\(rule.id.uuidString)-\(Int(day.timeIntervalSince1970))",
                        source: .scheduleRule,
                        courseID: rule.courseID,
                        title: course?.name ?? String(localized: "Ders bulunamadı"),
                        detail: course?.code ?? "",
                        startDate: start,
                        endDate: end,
                        location: rule.location,
                        status: String(localized: "Haftalık program")
                    )
                )
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return result.sorted(by: itemOrder)
    }

    private static func itemOrder(_ lhs: HomeLessonItem, _ rhs: HomeLessonItem) -> Bool {
        if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
        if lhs.title != rhs.title { return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
        return lhs.id < rhs.id
    }
}

enum HomeViewModel {
    static func snapshot(
        now: Date,
        calendar: Calendar = .current,
        lectures: [Lecture],
        tasks: [StudyTask],
        rules: [CourseScheduleRule] = [],
        courses: [Course] = []
    ) -> HomeSnapshot {
        let today = calendar.startOfDay(for: now)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: today) ?? today
        let projectionEnd = calendar.date(byAdding: .day, value: 14, to: today) ?? weekEnd
        let courseNames = Dictionary(uniqueKeysWithValues: courses.map { ($0.id, $0.name) })

        let lectureItems = lectures.map { lecture in
            HomeLessonItem(
                id: "lecture-\(lecture.id.uuidString)",
                source: .lecture,
                courseID: lecture.courseID,
                title: lecture.title,
                detail: lecture.courseID.flatMap { courseNames[$0] } ?? String(localized: "Ders atanmamış"),
                startDate: lecture.date,
                endDate: nil,
                location: "",
                status: lecture.reviewStatus.title
            )
        }
        let projected = ScheduleOccurrenceProjector.project(
            rules: rules,
            courses: courses,
            from: today,
            through: projectionEnd,
            calendar: calendar
        )
        let explicitOccurrenceKeys = Set(lectureItems.map { occurrenceKey(courseID: $0.courseID, date: $0.startDate, calendar: calendar) })
        let deduplicatedProjection = projected.filter {
            !explicitOccurrenceKeys.contains(occurrenceKey(courseID: $0.courseID, date: $0.startDate, calendar: calendar))
        }
        let lessons = (lectureItems + deduplicatedProjection).sorted(by: lessonOrder)
        let todayTasks = tasksForDay(today, tasks: tasks, calendar: calendar)

        let weekDays: [HomeDaySnapshot] = (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return HomeDaySnapshot(
                date: day,
                lessons: lessons.filter { calendar.isDate($0.startDate, inSameDayAs: day) },
                tasks: tasksForDay(day, tasks: tasks, calendar: calendar)
            )
        }

        return HomeSnapshot(
            todayLessons: lessons.filter { calendar.isDate($0.startDate, inSameDayAs: now) },
            upcomingLessons: Array(lessons.filter { $0.startDate > now && !calendar.isDate($0.startDate, inSameDayAs: now) }.prefix(8)),
            todayTasks: todayTasks,
            completedTasks: todayTasks.filter(\.isCompleted).count,
            weekDays: weekDays
        )
    }

    private static func tasksForDay(_ day: Date, tasks: [StudyTask], calendar: Calendar) -> [StudyTask] {
        tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return calendar.isDate(due, inSameDayAs: day)
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private static func occurrenceKey(courseID: UUID?, date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return "\(courseID?.uuidString ?? "none")-\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)-\(parts.hour ?? 0)-\(parts.minute ?? 0)"
    }

    private static func lessonOrder(_ lhs: HomeLessonItem, _ rhs: HomeLessonItem) -> Bool {
        if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
        if lhs.source != rhs.source { return lhs.source == .lecture }
        return lhs.id < rhs.id
    }
}
