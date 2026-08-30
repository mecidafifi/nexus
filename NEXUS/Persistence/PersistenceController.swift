import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Course.self, StudyTask.self, StudyGoal.self, StudySession.self, StudyScheduleRule.self,
        AttendanceRecord.self,
        WorkoutRecord.self, WorkoutPlan.self, ExerciseDefinition.self, PlannedWorkoutExercise.self, PlannedWorkoutSession.self, CompletedExerciseLog.self,
        FinanceEntry.self, FinanceCategory.self, MonthlyBudget.self, RecurringTransaction.self, DebtRecord.self,
        NexusNote.self, NoteFolder.self, NoteTag.self, NoteTagAssignment.self,
        CalendarEntry.self, GradeRecord.self, UniversityCourse.self, OBSAssessment.self, GradeScaleBand.self,
        ProjectRecord.self, OrganizationTask.self, PlannedTaskPlacement.self, FocusSessionRecord.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration("NEXUS", schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
