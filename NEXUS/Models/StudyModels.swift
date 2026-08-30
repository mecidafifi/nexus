import Foundation
import SwiftData

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    var name: String
    var code: String
    var instructor: String
    var location: String
    var colorHex: String
    var semesterStart: Date?
    var semesterEnd: Date?
    var allowedAbsenceCount: Int = 3
    var examDate: Date?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, code: String = "", instructor: String = "", location: String = "", colorHex: String = "#78FF9A", semesterStart: Date? = nil, semesterEnd: Date? = nil, allowedAbsenceCount: Int = 3, examDate: Date? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.name = name; self.code = code; self.instructor = instructor
        self.location = location; self.colorHex = colorHex; self.semesterStart = semesterStart; self.semesterEnd = semesterEnd
        self.allowedAbsenceCount = max(allowedAbsenceCount, 0); self.examDate = examDate; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class StudyTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var courseID: UUID?
    var dueDate: Date?
    var statusRaw: String
    var priorityRaw: String
    var estimatedMinutes: Int
    var completedAt: Date?
    var externalCalendarEventIdentifier: String?
    var createdAt: Date
    var updatedAt: Date
    var overdueReviewedAt: Date?

    var status: StudyTaskStatus {
        get { StudyTaskStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }
    var priority: StudyTaskPriority {
        get { StudyTaskPriority(rawValue: priorityRaw) ?? .normal }
        set { priorityRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), title: String, details: String = "", courseID: UUID? = nil, dueDate: Date? = nil, status: StudyTaskStatus = .planned, priority: StudyTaskPriority = .normal, estimatedMinutes: Int = 60, externalCalendarEventIdentifier: String? = nil, overdueReviewedAt: Date? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.details = details; self.courseID = courseID; self.dueDate = dueDate
        self.statusRaw = status.rawValue; self.priorityRaw = priority.rawValue; self.estimatedMinutes = estimatedMinutes
        self.externalCalendarEventIdentifier = externalCalendarEventIdentifier; self.overdueReviewedAt = overdueReviewedAt
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class StudyGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var courseID: UUID?
    var targetMinutes: Int
    var periodRaw: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var updatedAt: Date

    var period: GoalPeriod {
        get { GoalPeriod(rawValue: periodRaw) ?? .weekly }
        set { periodRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), title: String, courseID: UUID? = nil, targetMinutes: Int = 300, period: GoalPeriod = .weekly, startDate: Date = .now, endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.courseID = courseID; self.targetMinutes = targetMinutes
        self.periodRaw = period.rawValue; self.startDate = startDate; self.endDate = endDate; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    var courseID: UUID?
    var startedAt: Date
    var durationMinutes: Int
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), courseID: UUID? = nil, startedAt: Date = .now, durationMinutes: Int = 45, note: String = "", createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID; self.startedAt = startedAt; self.durationMinutes = durationMinutes
        self.note = note; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
