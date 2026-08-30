import Foundation
import SwiftData

@MainActor
final class StudyViewModel: ObservableObject {
    @Published var section: StudySection = .overview
    @Published var searchText = ""
    @Published var taskStatusFilter: StudyTaskStatus?
    @Published var sort: StudySort = .dueDate
    @Published var statusMessageKey = "status.ready"
    @Published var errorMessage: String?

    func filteredTasks(_ tasks: [StudyTask]) -> [StudyTask] {
        let filtered = tasks.filter { task in
            let matchesText = searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText) || task.details.localizedCaseInsensitiveContains(searchText)
            let matchesStatus = taskStatusFilter == nil || task.status == taskStatusFilter
            return matchesText && matchesStatus
        }
        return filtered.sorted { lhs, rhs in
            switch sort {
            case .dueDate: (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            case .title: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .priority: priorityRank(lhs.priority) > priorityRank(rhs.priority)
            case .status: lhs.statusRaw < rhs.statusRaw
            }
        }
    }

    func filteredCourses(_ courses: [Course]) -> [Course] {
        courses.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.code.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func filteredGoals(_ goals: [StudyGoal]) -> [StudyGoal] {
        goals.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }.sorted { $0.endDate < $1.endDate }
    }

    func filteredSessions(_ sessions: [StudySession]) -> [StudySession] {
        sessions.filter { session in
            searchText.isEmpty || session.note.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.startedAt > $1.startedAt }
    }

    func completedTaskRatio(_ tasks: [StudyTask]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.status == .completed }.count) / Double(tasks.count)
    }

    func goalProgress(_ goal: StudyGoal, sessions: [StudySession], focusSessions: [FocusSessionRecord] = []) -> Double {
        guard goal.targetMinutes > 0 else { return 0 }
        let minutes = sessions.filter {
            $0.startedAt >= goal.startDate && $0.startedAt <= goal.endDate && (goal.courseID == nil || $0.courseID == goal.courseID)
        }.reduce(0) { $0 + max($1.durationMinutes, 0) }
        let focusSeconds = focusSessions.filter {
            $0.source.countsAsStudyTime && $0.startedAt >= goal.startDate && $0.startedAt <= goal.endDate &&
            (goal.courseID == nil || $0.courseID == goal.courseID)
        }.reduce(0) { $0 + max($1.elapsedSeconds, 0) }
        return min((Double(minutes) + Double(focusSeconds) / 60) / Double(goal.targetMinutes), 1)
    }

    func totalMinutes(_ sessions: [StudySession], since date: Date? = nil) -> Int {
        sessions.filter { date == nil || $0.startedAt >= date! }.reduce(0) { $0 + max($1.durationMinutes, 0) }
    }

    func totalFocusMinutes(_ sessions: [FocusSessionRecord], since date: Date? = nil) -> Int {
        let seconds = sessions.filter { $0.source.countsAsStudyTime && (date == nil || $0.startedAt >= date!) }
            .reduce(0) { $0 + max($1.elapsedSeconds, 0) }
        return seconds / 60
    }

    func courseName(for id: UUID?, courses: [Course]) -> String {
        guard let id else { return String(localized: "study.unassigned") }
        return courses.first(where: { $0.id == id })?.name ?? String(localized: "study.unassigned")
    }

    func saveCourse(_ course: Course?, name: String, code: String, instructor: String, location: String, context: ModelContext) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw StudyValidationError.emptyTitle }
        if let course {
            course.name = cleanName; course.code = code.trimmed; course.instructor = instructor.trimmed; course.location = location.trimmed; course.updatedAt = .now
        } else { context.insert(Course(name: cleanName, code: code.trimmed, instructor: instructor.trimmed, location: location.trimmed)) }
        try commit(context)
    }

    func saveTask(_ task: StudyTask?, title: String, details: String, courseID: UUID?, hasDueDate: Bool, dueDate: Date, status: StudyTaskStatus, priority: StudyTaskPriority, estimatedMinutes: Int, context: ModelContext) throws {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw StudyValidationError.emptyTitle }
        guard estimatedMinutes >= 0 else { throw StudyValidationError.invalidDuration }
        if let task {
            task.title = cleanTitle; task.details = details.trimmed; task.courseID = courseID; task.dueDate = hasDueDate ? dueDate : nil
            task.status = status; task.priority = priority; task.estimatedMinutes = estimatedMinutes; task.completedAt = status == .completed ? (task.completedAt ?? .now) : nil; task.updatedAt = .now
        } else {
            let value = StudyTask(title: cleanTitle, details: details.trimmed, courseID: courseID, dueDate: hasDueDate ? dueDate : nil, status: status, priority: priority, estimatedMinutes: estimatedMinutes)
            value.completedAt = status == .completed ? .now : nil; context.insert(value)
        }
        try commit(context)
    }

    func saveGoal(_ goal: StudyGoal?, title: String, courseID: UUID?, targetMinutes: Int, period: GoalPeriod, startDate: Date, endDate: Date, context: ModelContext) throws {
        guard !title.trimmed.isEmpty else { throw StudyValidationError.emptyTitle }
        guard targetMinutes > 0 else { throw StudyValidationError.invalidDuration }
        guard endDate >= startDate else { throw StudyValidationError.invalidDateRange }
        if let goal {
            goal.title = title.trimmed; goal.courseID = courseID; goal.targetMinutes = targetMinutes; goal.period = period; goal.startDate = startDate; goal.endDate = endDate; goal.updatedAt = .now
        } else { context.insert(StudyGoal(title: title.trimmed, courseID: courseID, targetMinutes: targetMinutes, period: period, startDate: startDate, endDate: endDate)) }
        try commit(context)
    }

    func saveSession(_ session: StudySession?, courseID: UUID?, startedAt: Date, durationMinutes: Int, note: String, context: ModelContext) throws {
        guard durationMinutes > 0 else { throw StudyValidationError.invalidDuration }
        if let session { session.courseID = courseID; session.startedAt = startedAt; session.durationMinutes = durationMinutes; session.note = note.trimmed; session.updatedAt = .now }
        else { context.insert(StudySession(courseID: courseID, startedAt: startedAt, durationMinutes: durationMinutes, note: note.trimmed)) }
        try commit(context)
    }

    func delete<T: PersistentModel>(_ value: T, context: ModelContext) throws {
        context.delete(value); try commit(context)
    }

    private func commit(_ context: ModelContext) throws {
        do { try context.save(); errorMessage = nil; statusMessageKey = "status.saved" }
        catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error }
    }

    private func priorityRank(_ priority: StudyTaskPriority) -> Int {
        switch priority { case .low: 0; case .normal: 1; case .high: 2; case .critical: 3 }
    }
}

enum StudyValidationError: LocalizedError {
    case emptyTitle, invalidDuration, invalidDateRange
    var errorDescription: String? {
        switch self {
        case .emptyTitle: String(localized: "validation.titleRequired")
        case .invalidDuration: String(localized: "validation.durationPositive")
        case .invalidDateRange: String(localized: "validation.dateRange")
        }
    }
}

private extension String { var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
