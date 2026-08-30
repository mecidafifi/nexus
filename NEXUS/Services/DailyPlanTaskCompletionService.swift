import Foundation
import SwiftData

enum DailyPlanTaskToggleError: LocalizedError {
    case unsupported
    case missingRecord

    var errorDescription: String? {
        switch self {
        case .unsupported: String(localized: "dailyPlan.task.unsupported")
        case .missingRecord: String(localized: "dailyPlan.task.missing")
        }
    }
}

@MainActor
enum DailyPlanTaskCompletionService {
    /// Toggles only the independent owning record. It never edits due dates,
    /// placements, lessons, attendance, assessments or finance records.
    @discardableResult
    static func toggle(
        item: DailyPlanItem,
        studyTasks: [StudyTask],
        organizationTasks: [OrganizationTask],
        calendarEntries: [CalendarEntry],
        plannedWorkouts: [PlannedWorkoutSession],
        context: ModelContext,
        now: Date = .now
    ) throws -> Bool {
        guard DailyPlanTaskProgressPolicy.isCompletable(item), let recordID = item.recordID else {
            throw DailyPlanTaskToggleError.unsupported
        }

        let isCompleted: Bool
        switch item.kind {
        case .studyTask:
            guard let task = studyTasks.first(where: { $0.id == recordID }), task.status != .cancelled else {
                throw DailyPlanTaskToggleError.missingRecord
            }
            isCompleted = task.status != .completed
            task.status = isCompleted ? .completed : .planned
            task.completedAt = isCompleted ? now : nil
            task.updatedAt = now
        case .organizationTask:
            guard let task = organizationTasks.first(where: { $0.id == recordID }), task.status != .cancelled else {
                throw DailyPlanTaskToggleError.missingRecord
            }
            isCompleted = task.status != .completed
            task.status = isCompleted ? .completed : .planned
            task.updatedAt = now
        case .calendar:
            guard let entry = calendarEntries.first(where: { $0.id == recordID }), entry.kind != .event else {
                throw DailyPlanTaskToggleError.missingRecord
            }
            entry.isCompleted.toggle()
            entry.updatedAt = now
            isCompleted = entry.isCompleted
        case .gym:
            guard let workout = plannedWorkouts.first(where: { $0.id == recordID }) else {
                throw DailyPlanTaskToggleError.missingRecord
            }
            workout.isCompleted.toggle()
            workout.updatedAt = now
            isCompleted = workout.isCompleted
        default:
            throw DailyPlanTaskToggleError.unsupported
        }

        try context.save()
        return isCompleted
    }
}
