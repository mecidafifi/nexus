import Foundation

enum StudyTaskStatus: String, CaseIterable, Codable, Identifiable {
    case planned, inProgress, completed, deferred, cancelled
    var id: String { rawValue }
    var titleKey: String { "task.status.\(rawValue)" }
}

enum StudyTaskPriority: String, CaseIterable, Codable, Identifiable {
    case low, normal, high, critical
    var id: String { rawValue }
    var titleKey: String { "priority.\(rawValue)" }
}

enum GoalPeriod: String, CaseIterable, Codable, Identifiable {
    case weekly, monthly, semester
    var id: String { rawValue }
    var titleKey: String { "goal.period.\(rawValue)" }
}

enum StudySort: String, CaseIterable, Identifiable {
    case dueDate, title, priority, status
    var id: String { rawValue }
    var titleKey: String { "sort.\(rawValue)" }
}

enum StudySection: String, CaseIterable, Identifiable {
    case overview, semesterSetup, courses, tasks, goals, sessions
    var id: String { rawValue }
    var titleKey: String { "study.section.\(rawValue)" }
    var symbol: String {
        switch self {
        case .overview: "chart.bar"
        case .semesterSetup: "calendar.badge.clock"
        case .courses: "books.vertical"
        case .tasks: "checklist"
        case .goals: "target"
        case .sessions: "timer"
        }
    }
}
