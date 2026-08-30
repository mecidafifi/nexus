import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

struct NEXUSBackup: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let courses: [CourseRecord]
    let tasks: [TaskRecord]
    let goals: [GoalRecord]
    let sessions: [SessionRecord]
    var noteFolders: [NoteFolderRecord]? = nil
    var noteTags: [NoteTagRecord]? = nil
    var notes: [NoteRecord]? = nil
    var noteTagAssignments: [NoteTagAssignmentRecord]? = nil
    var calendarEntries: [CalendarRecord]? = nil
    var attendanceRecords: [AttendanceRecordPayload]? = nil
    var universityCourses: [UniversityCoursePayload]? = nil
    var obsAssessments: [OBSAssessmentPayload]? = nil
    var gradeScaleBands: [GradeScaleBandPayload]? = nil
    var financeEntries: [FinanceEntryPayload]? = nil
    var financeCategories: [FinanceCategoryPayload]? = nil
    var monthlyBudgets: [MonthlyBudgetPayload]? = nil
    var recurringTransactions: [RecurringTransactionPayload]? = nil
    var debtRecords: [DebtRecordPayload]? = nil
    var workoutRecords: [WorkoutRecordPayload]? = nil
    var workoutPlans: [WorkoutPlanPayload]? = nil
    var exerciseDefinitions: [ExerciseDefinitionPayload]? = nil
    var plannedWorkoutExercises: [PlannedWorkoutExercisePayload]? = nil
    var plannedWorkoutSessions: [PlannedWorkoutSessionPayload]? = nil
    var completedExerciseLogs: [CompletedExerciseLogPayload]? = nil
    var studyScheduleRules: [StudyScheduleRulePayload]? = nil
    var organizationProjects: [OrganizationProjectPayload]? = nil
    var organizationTasks: [OrganizationTaskPayload]? = nil
    var plannedTaskPlacements: [PlannedTaskPlacementPayload]? = nil
    var focusSessions: [FocusSessionPayload]? = nil

    struct CourseRecord: Codable { let id: UUID; let name, code, instructor, location, colorHex: String; let createdAt, updatedAt: Date; var semesterStart: Date? = nil; var semesterEnd: Date? = nil; var allowedAbsenceCount: Int? = nil; var examDate: Date? = nil }
    struct TaskRecord: Codable { let id: UUID; let title, details: String; let courseID: UUID?; let dueDate: Date?; let status, priority: String; let estimatedMinutes: Int; let completedAt: Date?; let externalCalendarEventIdentifier: String?; let createdAt, updatedAt: Date; var overdueReviewedAt: Date? = nil }
    struct GoalRecord: Codable { let id: UUID; let title: String; let courseID: UUID?; let targetMinutes: Int; let period: String; let startDate, endDate, createdAt, updatedAt: Date }
    struct SessionRecord: Codable { let id: UUID; let courseID: UUID?; let startedAt: Date; let durationMinutes: Int; let note: String; let createdAt, updatedAt: Date }
    struct NoteFolderRecord: Codable { let id: UUID; let name: String; let createdAt: Date }
    struct NoteTagRecord: Codable { let id: UUID; let name: String; let createdAt: Date }
    struct NoteRecord: Codable { let id: UUID; let title, body: String; let folderID: UUID?; let isPinned: Bool; let createdAt, updatedAt: Date }
    struct NoteTagAssignmentRecord: Codable { let id, noteID, tagID: UUID }
    struct CalendarRecord: Codable { let id: UUID; let title, details: String; let startDate, endDate: Date; let isAllDay: Bool; let kind: String; let isCompleted: Bool; let reminderDate: Date?; let relatedRecordID, courseID: UUID?; let createdAt, updatedAt: Date }
    struct AttendanceRecordPayload: Codable { let id: UUID; let courseID: UUID?; let date: Date; let status, note: String; let occurrenceID: String?; let scheduleRuleID: UUID?; let createdAt, updatedAt: Date }
    struct StudyScheduleRulePayload: Codable { let id, courseID: UUID; let weekday, startMinutes, durationMinutes: Int; let effectiveStart: Date; let effectiveEnd: Date?; let locationOverride: String; let isActive: Bool; let createdAt, updatedAt: Date }
    struct UniversityCoursePayload: Codable { let id: UUID; let name, code, semester: String; let creditHours: Double; let linkedStudyCourseID: UUID?; let isActive: Bool; let createdAt, updatedAt: Date }
    struct OBSAssessmentPayload: Codable { let id, universityCourseID: UUID; let title, kind: String; let dueDate: Date; let maximumPoints: Double; let earnedPoints: Double?; let weightPercent: Double; let note: String; let createdAt, updatedAt: Date }
    struct GradeScaleBandPayload: Codable { let id: UUID; let letter: String; let minimumPercent, gradePoints: Double; let createdAt: Date }
    struct FinanceEntryPayload: Codable { let id: UUID; let date: Date; let title: String; let amountMinorUnits: Int; let currencyCode, category, type: String; let categoryID: UUID?; let createdAt, updatedAt: Date }
    struct FinanceCategoryPayload: Codable { let id: UUID; let name, type: String; let createdAt: Date }
    struct MonthlyBudgetPayload: Codable { let id: UUID; let monthStart: Date; let amountMinorUnits: Int; let currencyCode: String; let createdAt, updatedAt: Date }
    struct RecurringTransactionPayload: Codable { let id: UUID; let title: String; let amountMinorUnits: Int; let currencyCode, type: String; let categoryID: UUID?; let startDate, nextDate: Date; let cadence: String; let isActive: Bool; let note: String; let createdAt, updatedAt: Date }
    struct DebtRecordPayload: Codable { let id: UUID; let counterparty: String; let amountMinorUnits: Int; let currencyCode, direction: String; let dueDate: Date?; let status, note: String; let createdAt, updatedAt: Date }
    struct WorkoutRecordPayload: Codable { let id: UUID; let date: Date; let title: String; let durationMinutes: Int; let note: String; let planID: UUID?; let createdAt, updatedAt: Date }
    struct WorkoutPlanPayload: Codable { let id: UUID; let name, goal: String; let isActive: Bool; let nextSessionDate: Date?; let createdAt, updatedAt: Date }
    struct ExerciseDefinitionPayload: Codable { let id: UUID; let name, muscleGroup: String; let defaultSets, defaultReps: Int; let defaultWeight: Double; let createdAt, updatedAt: Date }
    struct PlannedWorkoutExercisePayload: Codable { let id, planID, exerciseID: UUID; let order, targetSets, targetReps: Int; let targetWeight: Double }
    struct PlannedWorkoutSessionPayload: Codable { let id: UUID; let planID: UUID?; let date: Date; let isCompleted: Bool; let note: String; let createdAt, updatedAt: Date }
    struct CompletedExerciseLogPayload: Codable { let id, sessionID, exerciseID: UUID; let sets, reps: Int; let weight: Double; let note: String }
    struct OrganizationProjectPayload: Codable { let id: UUID; let title, details: String; let dueDate: Date?; let isArchived: Bool; let priority, status: String; let createdAt, updatedAt: Date }
    struct OrganizationTaskPayload: Codable { let id, projectID: UUID; let parentTaskID: UUID?; let title, details: String; let dueDate: Date?; let priority, status: String; let order: Int; let overdueReviewedAt: Date?; let createdAt, updatedAt: Date }
    struct PlannedTaskPlacementPayload: Codable { let id: UUID; let source: String; let sourceRecordID: UUID; let planDate, startDate, endDate, createdAt, updatedAt: Date }
    struct FocusSessionPayload: Codable { let id: UUID; let title, source: String; let sourceRecordID, courseID: UUID?; let startedAt, endedAt: Date; let elapsedSeconds: Int; let plannedDurationSeconds: Int?; let outcome: String; let createdAt: Date }
}

enum BackupImportMode: String, CaseIterable, Identifiable { case merge, replace; var id: String { rawValue } }

enum BackupError: LocalizedError {
    case unsupportedVersion, duplicateIdentifiers, invalidRecord, invalidReference
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: String(localized: "backup.error.version")
        case .duplicateIdentifiers: String(localized: "backup.error.duplicates")
        case .invalidRecord: String(localized: "backup.error.invalid")
        case .invalidReference: String(localized: "backup.error.reference")
        }
    }
}

@MainActor
enum BackupService {
    static func export(from context: ModelContext) throws -> NEXUSBackup {
        let courses = try context.fetch(FetchDescriptor<Course>()).map { NEXUSBackup.CourseRecord(id: $0.id, name: $0.name, code: $0.code, instructor: $0.instructor, location: $0.location, colorHex: $0.colorHex, createdAt: $0.createdAt, updatedAt: $0.updatedAt, semesterStart: $0.semesterStart, semesterEnd: $0.semesterEnd, allowedAbsenceCount: $0.allowedAbsenceCount, examDate: $0.examDate) }
        let tasks = try context.fetch(FetchDescriptor<StudyTask>()).map { NEXUSBackup.TaskRecord(id: $0.id, title: $0.title, details: $0.details, courseID: $0.courseID, dueDate: $0.dueDate, status: $0.statusRaw, priority: $0.priorityRaw, estimatedMinutes: $0.estimatedMinutes, completedAt: $0.completedAt, externalCalendarEventIdentifier: $0.externalCalendarEventIdentifier, createdAt: $0.createdAt, updatedAt: $0.updatedAt, overdueReviewedAt: $0.overdueReviewedAt) }
        let goals = try context.fetch(FetchDescriptor<StudyGoal>()).map { NEXUSBackup.GoalRecord(id: $0.id, title: $0.title, courseID: $0.courseID, targetMinutes: $0.targetMinutes, period: $0.periodRaw, startDate: $0.startDate, endDate: $0.endDate, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let sessions = try context.fetch(FetchDescriptor<StudySession>()).map { NEXUSBackup.SessionRecord(id: $0.id, courseID: $0.courseID, startedAt: $0.startedAt, durationMinutes: $0.durationMinutes, note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let folders = try context.fetch(FetchDescriptor<NoteFolder>()).map { NEXUSBackup.NoteFolderRecord(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
        let tags = try context.fetch(FetchDescriptor<NoteTag>()).map { NEXUSBackup.NoteTagRecord(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
        let notes = try context.fetch(FetchDescriptor<NexusNote>()).map { NEXUSBackup.NoteRecord(id: $0.id, title: $0.title, body: $0.body, folderID: $0.folderID, isPinned: $0.isPinned, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let noteTags = try context.fetch(FetchDescriptor<NoteTagAssignment>()).map { NEXUSBackup.NoteTagAssignmentRecord(id: $0.id, noteID: $0.noteID, tagID: $0.tagID) }
        let calendar = try context.fetch(FetchDescriptor<CalendarEntry>()).map { NEXUSBackup.CalendarRecord(id: $0.id, title: $0.title, details: $0.details, startDate: $0.startDate, endDate: $0.endDate, isAllDay: $0.isAllDay, kind: $0.kindRaw, isCompleted: $0.isCompleted, reminderDate: $0.reminderDate, relatedRecordID: $0.relatedRecordID, courseID: $0.courseID, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let attendance = try context.fetch(FetchDescriptor<AttendanceRecord>()).map { NEXUSBackup.AttendanceRecordPayload(id: $0.id, courseID: $0.courseID, date: $0.date, status: $0.status.rawValue, note: $0.note, occurrenceID: $0.occurrenceID.isEmpty ? nil : $0.occurrenceID, scheduleRuleID: $0.scheduleRuleID, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let schedules = try context.fetch(FetchDescriptor<StudyScheduleRule>()).map { NEXUSBackup.StudyScheduleRulePayload(id: $0.id, courseID: $0.courseID, weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes, effectiveStart: $0.effectiveStart, effectiveEnd: $0.effectiveEnd, locationOverride: $0.locationOverride, isActive: $0.isActive, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let universityCourses = try context.fetch(FetchDescriptor<UniversityCourse>()).map { NEXUSBackup.UniversityCoursePayload(id: $0.id, name: $0.name, code: $0.code, semester: $0.semester, creditHours: $0.creditHours, linkedStudyCourseID: $0.linkedStudyCourseID, isActive: $0.isActive, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let obsAssessments = try context.fetch(FetchDescriptor<OBSAssessment>()).map { NEXUSBackup.OBSAssessmentPayload(id: $0.id, universityCourseID: $0.universityCourseID, title: $0.title, kind: $0.kindRaw, dueDate: $0.dueDate, maximumPoints: $0.maximumPoints, earnedPoints: $0.earnedPoints, weightPercent: $0.weightPercent, note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let bands = try context.fetch(FetchDescriptor<GradeScaleBand>()).map { NEXUSBackup.GradeScaleBandPayload(id: $0.id, letter: $0.letter, minimumPercent: $0.minimumPercent, gradePoints: $0.gradePoints, createdAt: $0.createdAt) }
        let financeEntries = try context.fetch(FetchDescriptor<FinanceEntry>()).map { NEXUSBackup.FinanceEntryPayload(id: $0.id, date: $0.date, title: $0.title, amountMinorUnits: $0.normalizedAmountMinorUnits, currencyCode: $0.currencyCode, category: $0.category, type: $0.type.rawValue, categoryID: $0.categoryID, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let financeCategories = try context.fetch(FetchDescriptor<FinanceCategory>()).map { NEXUSBackup.FinanceCategoryPayload(id: $0.id, name: $0.name, type: $0.type.rawValue, createdAt: $0.createdAt) }
        let budgets = try context.fetch(FetchDescriptor<MonthlyBudget>()).map { NEXUSBackup.MonthlyBudgetPayload(id: $0.id, monthStart: $0.monthStart, amountMinorUnits: $0.amountMinorUnits, currencyCode: $0.currencyCode, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let recurring = try context.fetch(FetchDescriptor<RecurringTransaction>()).map { NEXUSBackup.RecurringTransactionPayload(id: $0.id, title: $0.title, amountMinorUnits: $0.amountMinorUnits, currencyCode: $0.currencyCode, type: $0.type.rawValue, categoryID: $0.categoryID, startDate: $0.startDate, nextDate: $0.nextDate, cadence: $0.cadence.rawValue, isActive: $0.isActive, note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let debts = try context.fetch(FetchDescriptor<DebtRecord>()).map { NEXUSBackup.DebtRecordPayload(id: $0.id, counterparty: $0.counterparty, amountMinorUnits: $0.amountMinorUnits, currencyCode: $0.currencyCode, direction: $0.direction.rawValue, dueDate: $0.dueDate, status: $0.status.rawValue, note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let workouts = try context.fetch(FetchDescriptor<WorkoutRecord>()).map { NEXUSBackup.WorkoutRecordPayload(id: $0.id, date: $0.date, title: $0.title, durationMinutes: $0.durationMinutes, note: $0.note, planID: $0.planID, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>()).map { NEXUSBackup.WorkoutPlanPayload(id: $0.id, name: $0.name, goal: $0.goal, isActive: $0.isActive, nextSessionDate: $0.nextSessionDate, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let exercises = try context.fetch(FetchDescriptor<ExerciseDefinition>()).map { NEXUSBackup.ExerciseDefinitionPayload(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup, defaultSets: $0.defaultSets, defaultReps: $0.defaultReps, defaultWeight: $0.defaultWeight, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let planExercises = try context.fetch(FetchDescriptor<PlannedWorkoutExercise>()).map { NEXUSBackup.PlannedWorkoutExercisePayload(id: $0.id, planID: $0.planID, exerciseID: $0.exerciseID, order: $0.order, targetSets: $0.targetSets, targetReps: $0.targetReps, targetWeight: $0.targetWeight) }
        let plannedSessions = try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).map { NEXUSBackup.PlannedWorkoutSessionPayload(id: $0.id, planID: $0.planID, date: $0.date, isCompleted: $0.isCompleted, note: $0.note, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let logs = try context.fetch(FetchDescriptor<CompletedExerciseLog>()).map { NEXUSBackup.CompletedExerciseLogPayload(id: $0.id, sessionID: $0.sessionID, exerciseID: $0.exerciseID, sets: $0.sets, reps: $0.reps, weight: $0.weight, note: $0.note) }
        let projects = try context.fetch(FetchDescriptor<ProjectRecord>()).map { NEXUSBackup.OrganizationProjectPayload(id: $0.id, title: $0.title, details: $0.details, dueDate: $0.dueDate, isArchived: $0.isArchived, priority: $0.priority.rawValue, status: $0.status.rawValue, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let organizationTasks = try context.fetch(FetchDescriptor<OrganizationTask>()).map { NEXUSBackup.OrganizationTaskPayload(id: $0.id, projectID: $0.projectID, parentTaskID: $0.parentTaskID, title: $0.title, details: $0.details, dueDate: $0.dueDate, priority: $0.priority.rawValue, status: $0.status.rawValue, order: $0.order, overdueReviewedAt: $0.overdueReviewedAt, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let placements = try context.fetch(FetchDescriptor<PlannedTaskPlacement>()).map { NEXUSBackup.PlannedTaskPlacementPayload(id: $0.id, source: $0.source.rawValue, sourceRecordID: $0.sourceRecordID, planDate: $0.planDate, startDate: $0.startDate, endDate: $0.endDate, createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        let focus = try context.fetch(FetchDescriptor<FocusSessionRecord>()).map { NEXUSBackup.FocusSessionPayload(id: $0.id, title: $0.title, source: $0.source.rawValue, sourceRecordID: $0.sourceRecordID, courseID: $0.courseID, startedAt: $0.startedAt, endedAt: $0.endedAt, elapsedSeconds: $0.elapsedSeconds, plannedDurationSeconds: $0.plannedDurationSeconds, outcome: $0.outcome.rawValue, createdAt: $0.createdAt) }
        return NEXUSBackup(schemaVersion: 9, createdAt: .now, courses: courses, tasks: tasks, goals: goals, sessions: sessions, noteFolders: folders, noteTags: tags, notes: notes, noteTagAssignments: noteTags, calendarEntries: calendar, attendanceRecords: attendance, universityCourses: universityCourses, obsAssessments: obsAssessments, gradeScaleBands: bands, financeEntries: financeEntries, financeCategories: financeCategories, monthlyBudgets: budgets, recurringTransactions: recurring, debtRecords: debts, workoutRecords: workouts, workoutPlans: plans, exerciseDefinitions: exercises, plannedWorkoutExercises: planExercises, plannedWorkoutSessions: plannedSessions, completedExerciseLogs: logs, studyScheduleRules: schedules, organizationProjects: projects, organizationTasks: organizationTasks, plannedTaskPlacements: placements, focusSessions: focus)
    }

    static func encoded(_ backup: NEXUSBackup) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decoded(_ data: Data) throws -> NEXUSBackup {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(NEXUSBackup.self, from: data)
        try validate(backup)
        return backup
    }

    static func validate(_ backup: NEXUSBackup) throws {
        guard (1...9).contains(backup.schemaVersion) else { throw BackupError.unsupportedVersion }
        let allIDs = backup.courses.map(\.id) + backup.tasks.map(\.id) + backup.goals.map(\.id) + backup.sessions.map(\.id) + (backup.noteFolders ?? []).map(\.id) + (backup.noteTags ?? []).map(\.id) + (backup.notes ?? []).map(\.id) + (backup.noteTagAssignments ?? []).map(\.id) + (backup.calendarEntries ?? []).map(\.id) + (backup.attendanceRecords ?? []).map(\.id) + (backup.universityCourses ?? []).map(\.id) + (backup.obsAssessments ?? []).map(\.id) + (backup.gradeScaleBands ?? []).map(\.id) + (backup.financeEntries ?? []).map(\.id) + (backup.financeCategories ?? []).map(\.id) + (backup.monthlyBudgets ?? []).map(\.id) + (backup.recurringTransactions ?? []).map(\.id) + (backup.debtRecords ?? []).map(\.id) + (backup.workoutRecords ?? []).map(\.id) + (backup.workoutPlans ?? []).map(\.id) + (backup.exerciseDefinitions ?? []).map(\.id) + (backup.plannedWorkoutExercises ?? []).map(\.id) + (backup.plannedWorkoutSessions ?? []).map(\.id) + (backup.completedExerciseLogs ?? []).map(\.id) + (backup.studyScheduleRules ?? []).map(\.id) + (backup.organizationProjects ?? []).map(\.id) + (backup.organizationTasks ?? []).map(\.id) + (backup.plannedTaskPlacements ?? []).map(\.id) + (backup.focusSessions ?? []).map(\.id)
        guard Set(allIDs).count == allIDs.count else { throw BackupError.duplicateIdentifiers }
        guard backup.courses.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && ($0.allowedAbsenceCount ?? 0) >= 0 && ($0.semesterStart == nil || $0.semesterEnd == nil || $0.semesterEnd! >= $0.semesterStart!) }),
              backup.tasks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.estimatedMinutes >= 0 && StudyTaskStatus(rawValue: $0.status) != nil && StudyTaskPriority(rawValue: $0.priority) != nil }),
              backup.goals.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.targetMinutes > 0 && $0.endDate >= $0.startDate && GoalPeriod(rawValue: $0.period) != nil }),
              backup.sessions.allSatisfy({ $0.durationMinutes > 0 }),
              (backup.notes ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              (backup.noteFolders ?? []).allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              (backup.noteTags ?? []).allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              (backup.calendarEntries ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.endDate >= $0.startDate && CalendarEntryKind(rawValue: $0.kind) != nil && ($0.reminderDate == nil || $0.reminderDate! <= $0.startDate) }),
              (backup.attendanceRecords ?? []).allSatisfy({ AttendanceStatus(rawValue: $0.status) != nil }),
              (backup.universityCourses ?? []).allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.creditHours > 0 }),
              (backup.obsAssessments ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && AssessmentKind(rawValue: $0.kind) != nil && $0.maximumPoints > 0 && (0...100).contains($0.weightPercent) && ($0.earnedPoints == nil || (0...$0.maximumPoints).contains($0.earnedPoints!)) }),
              (backup.gradeScaleBands ?? []).allSatisfy({ !$0.letter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (0...100).contains($0.minimumPercent) && $0.gradePoints >= 0 }),
              (backup.financeEntries ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.amountMinorUnits > 0 && FinanceTransactionType(rawValue: $0.type) != nil }),
              (backup.financeCategories ?? []).allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && FinanceTransactionType(rawValue: $0.type) != nil }),
              (backup.monthlyBudgets ?? []).allSatisfy({ $0.amountMinorUnits >= 0 }),
              (backup.recurringTransactions ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.amountMinorUnits > 0 && FinanceTransactionType(rawValue: $0.type) != nil && RecurrenceCadence(rawValue: $0.cadence) != nil }),
              (backup.debtRecords ?? []).allSatisfy({ !$0.counterparty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.amountMinorUnits > 0 && DebtDirection(rawValue: $0.direction) != nil && DebtStatus(rawValue: $0.status) != nil }),
              (backup.workoutRecords ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.durationMinutes > 0 }),
              (backup.workoutPlans ?? []).allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              (backup.exerciseDefinitions ?? []).allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.defaultSets > 0 && $0.defaultReps > 0 && $0.defaultWeight >= 0 }),
              (backup.plannedWorkoutExercises ?? []).allSatisfy({ $0.targetSets > 0 && $0.targetReps > 0 && $0.targetWeight >= 0 }),
              (backup.completedExerciseLogs ?? []).allSatisfy({ $0.sets > 0 && $0.reps > 0 && $0.weight >= 0 }),
              (backup.studyScheduleRules ?? []).allSatisfy({ (1...7).contains($0.weekday) && (0...1_439).contains($0.startMinutes) && (10...720).contains($0.durationMinutes) && ($0.effectiveEnd == nil || $0.effectiveEnd! >= $0.effectiveStart) }),
              (backup.organizationProjects ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && OrganizationPriority(rawValue: $0.priority) != nil && OrganizationStatus(rawValue: $0.status) != nil }),
              (backup.organizationTasks ?? []).allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && OrganizationPriority(rawValue: $0.priority) != nil && OrganizationStatus(rawValue: $0.status) != nil && $0.parentTaskID != $0.id }),
              (backup.plannedTaskPlacements ?? []).allSatisfy({ TaskPlacementSource(rawValue: $0.source) != nil && $0.endDate > $0.startDate && Calendar.current.isDate($0.startDate, inSameDayAs: $0.planDate) && Calendar.current.isDate($0.endDate.addingTimeInterval(-1), inSameDayAs: $0.planDate) }),
              (backup.focusSessions ?? []).allSatisfy({ record in
                  guard !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        let source = FocusSource(rawValue: record.source), FocusOutcome(rawValue: record.outcome) != nil,
                        record.elapsedSeconds > 0, record.endedAt >= record.startedAt,
                        record.plannedDurationSeconds == nil || record.plannedDurationSeconds! > 0 else { return false }
                  return source == .studyContext ? record.sourceRecordID == nil : record.sourceRecordID != nil
              }) else { throw BackupError.invalidRecord }
        let courseIDs = Set(backup.courses.map(\.id))
        let references = backup.tasks.compactMap(\.courseID) + backup.goals.compactMap(\.courseID) + backup.sessions.compactMap(\.courseID)
        let scheduleIDs = Set((backup.studyScheduleRules ?? []).map(\.id))
        let occurrenceIDs = (backup.attendanceRecords ?? []).compactMap(\.occurrenceID).filter { !$0.isEmpty }
        guard references.allSatisfy(courseIDs.contains),
              (backup.studyScheduleRules ?? []).allSatisfy({ courseIDs.contains($0.courseID) }),
              (backup.attendanceRecords ?? []).compactMap(\.scheduleRuleID).allSatisfy(scheduleIDs.contains),
              Set(occurrenceIDs).count == occurrenceIDs.count else { throw BackupError.invalidReference }
        let folderIDs = Set((backup.noteFolders ?? []).map(\.id)); let tagIDs = Set((backup.noteTags ?? []).map(\.id)); let noteIDs = Set((backup.notes ?? []).map(\.id))
        guard (backup.notes ?? []).compactMap(\.folderID).allSatisfy(folderIDs.contains),
              (backup.noteTagAssignments ?? []).allSatisfy({ noteIDs.contains($0.noteID) && tagIDs.contains($0.tagID) }) else { throw BackupError.invalidReference }
        let universityCourseIDs = Set((backup.universityCourses ?? []).map(\.id))
        guard (backup.attendanceRecords ?? []).compactMap(\.courseID).allSatisfy(courseIDs.contains),
              (backup.universityCourses ?? []).compactMap(\.linkedStudyCourseID).allSatisfy(courseIDs.contains),
              (backup.obsAssessments ?? []).allSatisfy({ universityCourseIDs.contains($0.universityCourseID) }),
              Set((backup.gradeScaleBands ?? []).map(\.minimumPercent)).count == (backup.gradeScaleBands ?? []).count else { throw BackupError.invalidReference }
        let categoryIDs = Set((backup.financeCategories ?? []).map(\.id)); let planIDs = Set((backup.workoutPlans ?? []).map(\.id)); let exerciseIDs = Set((backup.exerciseDefinitions ?? []).map(\.id)); let workoutIDs = Set((backup.workoutRecords ?? []).map(\.id))
        guard (backup.financeEntries ?? []).compactMap(\.categoryID).allSatisfy(categoryIDs.contains),
              (backup.recurringTransactions ?? []).compactMap(\.categoryID).allSatisfy(categoryIDs.contains),
              (backup.workoutRecords ?? []).compactMap(\.planID).allSatisfy(planIDs.contains),
              (backup.plannedWorkoutSessions ?? []).compactMap(\.planID).allSatisfy(planIDs.contains),
              (backup.plannedWorkoutExercises ?? []).allSatisfy({ planIDs.contains($0.planID) && exerciseIDs.contains($0.exerciseID) }),
              (backup.completedExerciseLogs ?? []).allSatisfy({ workoutIDs.contains($0.sessionID) && exerciseIDs.contains($0.exerciseID) }) else { throw BackupError.invalidReference }
        let organizationProjectIDs = Set((backup.organizationProjects ?? []).map(\.id))
        let organizationTaskIDs = Set((backup.organizationTasks ?? []).map(\.id))
        guard (backup.organizationTasks ?? []).allSatisfy({ organizationProjectIDs.contains($0.projectID) && ($0.parentTaskID == nil || organizationTaskIDs.contains($0.parentTaskID!)) }) else { throw BackupError.invalidReference }
        let studyTaskIDs = Set(backup.tasks.map(\.id)); let calendarEntryIDs = Set((backup.calendarEntries ?? []).map(\.id))
        let placementKeys = (backup.plannedTaskPlacements ?? []).map { "\($0.source):\($0.sourceRecordID.uuidString.lowercased())" }
        guard Set(placementKeys).count == placementKeys.count,
              (backup.plannedTaskPlacements ?? []).allSatisfy({ record in
            switch TaskPlacementSource(rawValue: record.source)! {
            case .studyTask: studyTaskIDs.contains(record.sourceRecordID)
            case .organizationTask: organizationTaskIDs.contains(record.sourceRecordID)
            case .calendarTask: calendarEntryIDs.contains(record.sourceRecordID)
            }
        }) else { throw BackupError.invalidReference }
    }

    static func apply(_ backup: NEXUSBackup, mode: BackupImportMode, to context: ModelContext) throws {
        try validate(backup)
        if mode == .replace {
            try context.fetch(FetchDescriptor<FocusSessionRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<PlannedTaskPlacement>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<OrganizationTask>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<ProjectRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<StudyScheduleRule>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<CompletedExerciseLog>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<PlannedWorkoutExercise>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<WorkoutRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<ExerciseDefinition>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<WorkoutPlan>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<RecurringTransaction>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<FinanceEntry>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<MonthlyBudget>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<DebtRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<FinanceCategory>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<NoteTagAssignment>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<NexusNote>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<NoteFolder>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<NoteTag>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<CalendarEntry>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<AttendanceRecord>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<OBSAssessment>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<UniversityCourse>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<GradeScaleBand>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<StudyTask>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<StudyGoal>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<StudySession>()).forEach(context.delete)
            try context.fetch(FetchDescriptor<Course>()).forEach(context.delete)
        }
        var existingCourses = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Course>()).map { ($0.id, $0) })
        for record in backup.courses {
            if let value = existingCourses[record.id] { value.name = record.name; value.code = record.code; value.instructor = record.instructor; value.location = record.location; value.colorHex = record.colorHex; value.semesterStart = record.semesterStart; value.semesterEnd = record.semesterEnd; value.allowedAbsenceCount = record.allowedAbsenceCount ?? value.allowedAbsenceCount; value.examDate = record.examDate; value.updatedAt = record.updatedAt }
            else { let value = Course(id: record.id, name: record.name, code: record.code, instructor: record.instructor, location: record.location, colorHex: record.colorHex, semesterStart: record.semesterStart, semesterEnd: record.semesterEnd, allowedAbsenceCount: record.allowedAbsenceCount ?? 3, examDate: record.examDate, createdAt: record.createdAt, updatedAt: record.updatedAt); context.insert(value); existingCourses[record.id] = value }
        }
        let existingSchedules = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudyScheduleRule>()).map { ($0.id, $0) })
        for record in backup.studyScheduleRules ?? [] {
            if let value = existingSchedules[record.id] { value.courseID = record.courseID; value.weekday = record.weekday; value.startMinutes = record.startMinutes; value.durationMinutes = record.durationMinutes; value.effectiveStart = record.effectiveStart; value.effectiveEnd = record.effectiveEnd; value.locationOverride = record.locationOverride; value.isActive = record.isActive; value.updatedAt = record.updatedAt }
            else { context.insert(StudyScheduleRule(id: record.id, courseID: record.courseID, weekday: record.weekday, startMinutes: record.startMinutes, durationMinutes: record.durationMinutes, effectiveStart: record.effectiveStart, effectiveEnd: record.effectiveEnd, locationOverride: record.locationOverride, isActive: record.isActive, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingTasks = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudyTask>()).map { ($0.id, $0) })
        for record in backup.tasks {
            if let value = existingTasks[record.id] { value.title = record.title; value.details = record.details; value.courseID = record.courseID; value.dueDate = record.dueDate; value.statusRaw = record.status; value.priorityRaw = record.priority; value.estimatedMinutes = record.estimatedMinutes; value.completedAt = record.completedAt; value.externalCalendarEventIdentifier = record.externalCalendarEventIdentifier; value.overdueReviewedAt = record.overdueReviewedAt; value.updatedAt = record.updatedAt }
            else { let value = StudyTask(id: record.id, title: record.title, details: record.details, courseID: record.courseID, dueDate: record.dueDate, status: StudyTaskStatus(rawValue: record.status)!, priority: StudyTaskPriority(rawValue: record.priority)!, estimatedMinutes: record.estimatedMinutes, externalCalendarEventIdentifier: record.externalCalendarEventIdentifier, overdueReviewedAt: record.overdueReviewedAt, createdAt: record.createdAt, updatedAt: record.updatedAt); value.completedAt = record.completedAt; context.insert(value) }
        }
        let existingGoals = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudyGoal>()).map { ($0.id, $0) })
        for record in backup.goals {
            if let value = existingGoals[record.id] { value.title = record.title; value.courseID = record.courseID; value.targetMinutes = record.targetMinutes; value.periodRaw = record.period; value.startDate = record.startDate; value.endDate = record.endDate; value.updatedAt = record.updatedAt }
            else { context.insert(StudyGoal(id: record.id, title: record.title, courseID: record.courseID, targetMinutes: record.targetMinutes, period: GoalPeriod(rawValue: record.period)!, startDate: record.startDate, endDate: record.endDate, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingSessions = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudySession>()).map { ($0.id, $0) })
        for record in backup.sessions {
            if let value = existingSessions[record.id] { value.courseID = record.courseID; value.startedAt = record.startedAt; value.durationMinutes = record.durationMinutes; value.note = record.note; value.updatedAt = record.updatedAt }
            else { context.insert(StudySession(id: record.id, courseID: record.courseID, startedAt: record.startedAt, durationMinutes: record.durationMinutes, note: record.note, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingFolders = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<NoteFolder>()).map { ($0.id, $0) })
        for record in backup.noteFolders ?? [] { if let value = existingFolders[record.id] { value.name = record.name } else { context.insert(NoteFolder(id: record.id, name: record.name, createdAt: record.createdAt)) } }
        let existingTags = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<NoteTag>()).map { ($0.id, $0) })
        for record in backup.noteTags ?? [] { if let value = existingTags[record.id] { value.name = record.name } else { context.insert(NoteTag(id: record.id, name: record.name, createdAt: record.createdAt)) } }
        let existingNotes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<NexusNote>()).map { ($0.id, $0) })
        for record in backup.notes ?? [] { if let value = existingNotes[record.id] { value.title = record.title; value.body = record.body; value.folderID = record.folderID; value.isPinned = record.isPinned; value.updatedAt = record.updatedAt } else { context.insert(NexusNote(id: record.id, title: record.title, body: record.body, folderID: record.folderID, isPinned: record.isPinned, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingAssignments = Set(try context.fetch(FetchDescriptor<NoteTagAssignment>()).map(\.id))
        for record in backup.noteTagAssignments ?? [] where !existingAssignments.contains(record.id) { context.insert(NoteTagAssignment(id: record.id, noteID: record.noteID, tagID: record.tagID)) }
        let existingCalendar = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CalendarEntry>()).map { ($0.id, $0) })
        for record in backup.calendarEntries ?? [] {
            if let value = existingCalendar[record.id] { value.title = record.title; value.details = record.details; value.startDate = record.startDate; value.endDate = record.endDate; value.isAllDay = record.isAllDay; value.kindRaw = record.kind; value.isCompleted = record.isCompleted; value.reminderDate = record.reminderDate; value.relatedRecordID = record.relatedRecordID; value.courseID = record.courseID; value.updatedAt = record.updatedAt }
            else { context.insert(CalendarEntry(id: record.id, title: record.title, details: record.details, startDate: record.startDate, endDate: record.endDate, isAllDay: record.isAllDay, kind: CalendarEntryKind(rawValue: record.kind)!, isCompleted: record.isCompleted, reminderDate: record.reminderDate, relatedRecordID: record.relatedRecordID, courseID: record.courseID, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingAttendance = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<AttendanceRecord>()).map { ($0.id, $0) })
        for record in backup.attendanceRecords ?? [] { if let value = existingAttendance[record.id] { value.courseID = record.courseID; value.date = record.date; value.status = AttendanceStatus(rawValue: record.status)!; value.note = record.note; value.occurrenceID = record.occurrenceID ?? ""; value.scheduleRuleID = record.scheduleRuleID; value.updatedAt = record.updatedAt } else { context.insert(AttendanceRecord(id: record.id, courseID: record.courseID, date: record.date, status: AttendanceStatus(rawValue: record.status)!, note: record.note, occurrenceID: record.occurrenceID ?? "", scheduleRuleID: record.scheduleRuleID, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingUniversityCourses = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<UniversityCourse>()).map { ($0.id, $0) })
        for record in backup.universityCourses ?? [] { if let value = existingUniversityCourses[record.id] { value.name = record.name; value.code = record.code; value.semester = record.semester; value.creditHours = record.creditHours; value.linkedStudyCourseID = record.linkedStudyCourseID; value.isActive = record.isActive; value.updatedAt = record.updatedAt } else { context.insert(UniversityCourse(id: record.id, name: record.name, code: record.code, semester: record.semester, creditHours: record.creditHours, linkedStudyCourseID: record.linkedStudyCourseID, isActive: record.isActive, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingOBSAssessments = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<OBSAssessment>()).map { ($0.id, $0) })
        for record in backup.obsAssessments ?? [] { if let value = existingOBSAssessments[record.id] { value.universityCourseID = record.universityCourseID; value.title = record.title; value.kindRaw = record.kind; value.dueDate = record.dueDate; value.maximumPoints = record.maximumPoints; value.earnedPoints = record.earnedPoints; value.weightPercent = record.weightPercent; value.note = record.note; value.updatedAt = record.updatedAt } else { context.insert(OBSAssessment(id: record.id, universityCourseID: record.universityCourseID, title: record.title, kind: AssessmentKind(rawValue: record.kind)!, dueDate: record.dueDate, maximumPoints: record.maximumPoints, earnedPoints: record.earnedPoints, weightPercent: record.weightPercent, note: record.note, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingBands = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<GradeScaleBand>()).map { ($0.id, $0) })
        for record in backup.gradeScaleBands ?? [] { if let value = existingBands[record.id] { value.letter = record.letter; value.minimumPercent = record.minimumPercent; value.gradePoints = record.gradePoints } else { context.insert(GradeScaleBand(id: record.id, letter: record.letter, minimumPercent: record.minimumPercent, gradePoints: record.gradePoints, createdAt: record.createdAt)) } }
        let existingFinanceCategories = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<FinanceCategory>()).map { ($0.id, $0) })
        for record in backup.financeCategories ?? [] { if let value = existingFinanceCategories[record.id] { value.name = record.name; value.type = FinanceTransactionType(rawValue: record.type)! } else { context.insert(FinanceCategory(id: record.id, name: record.name, type: FinanceTransactionType(rawValue: record.type)!, createdAt: record.createdAt)) } }
        let existingFinanceEntries = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<FinanceEntry>()).map { ($0.id, $0) })
        for record in backup.financeEntries ?? [] { if let value = existingFinanceEntries[record.id] { value.date = record.date; value.title = record.title; value.amountMinorUnits = record.amountMinorUnits; value.currencyCode = record.currencyCode; value.category = record.category; value.type = FinanceTransactionType(rawValue: record.type)!; value.categoryID = record.categoryID; value.updatedAt = record.updatedAt } else { context.insert(FinanceEntry(id: record.id, date: record.date, title: record.title, amountMinorUnits: record.amountMinorUnits, currencyCode: record.currencyCode, category: record.category, type: FinanceTransactionType(rawValue: record.type)!, categoryID: record.categoryID, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingBudgets = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MonthlyBudget>()).map { ($0.id, $0) })
        for record in backup.monthlyBudgets ?? [] { if let value = existingBudgets[record.id] { value.monthStart = record.monthStart; value.amountMinorUnits = record.amountMinorUnits; value.currencyCode = record.currencyCode; value.updatedAt = record.updatedAt } else { context.insert(MonthlyBudget(id: record.id, monthStart: record.monthStart, amountMinorUnits: record.amountMinorUnits, currencyCode: record.currencyCode, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingRecurring = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<RecurringTransaction>()).map { ($0.id, $0) })
        for record in backup.recurringTransactions ?? [] { if let value = existingRecurring[record.id] { value.title = record.title; value.amountMinorUnits = record.amountMinorUnits; value.currencyCode = record.currencyCode; value.type = FinanceTransactionType(rawValue: record.type)!; value.categoryID = record.categoryID; value.startDate = record.startDate; value.nextDate = record.nextDate; value.cadence = RecurrenceCadence(rawValue: record.cadence)!; value.isActive = record.isActive; value.note = record.note; value.updatedAt = record.updatedAt } else { context.insert(RecurringTransaction(id: record.id, title: record.title, amountMinorUnits: record.amountMinorUnits, currencyCode: record.currencyCode, type: FinanceTransactionType(rawValue: record.type)!, categoryID: record.categoryID, startDate: record.startDate, nextDate: record.nextDate, cadence: RecurrenceCadence(rawValue: record.cadence)!, isActive: record.isActive, note: record.note, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingDebts = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<DebtRecord>()).map { ($0.id, $0) })
        for record in backup.debtRecords ?? [] { if let value = existingDebts[record.id] { value.counterparty = record.counterparty; value.amountMinorUnits = record.amountMinorUnits; value.currencyCode = record.currencyCode; value.direction = DebtDirection(rawValue: record.direction)!; value.dueDate = record.dueDate; value.status = DebtStatus(rawValue: record.status)!; value.note = record.note; value.updatedAt = record.updatedAt } else { context.insert(DebtRecord(id: record.id, counterparty: record.counterparty, amountMinorUnits: record.amountMinorUnits, currencyCode: record.currencyCode, direction: DebtDirection(rawValue: record.direction)!, dueDate: record.dueDate, status: DebtStatus(rawValue: record.status)!, note: record.note, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingPlans = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WorkoutPlan>()).map { ($0.id, $0) })
        for record in backup.workoutPlans ?? [] { if let value = existingPlans[record.id] { value.name = record.name; value.goal = record.goal; value.isActive = record.isActive; value.nextSessionDate = record.nextSessionDate; value.updatedAt = record.updatedAt } else { context.insert(WorkoutPlan(id: record.id, name: record.name, goal: record.goal, isActive: record.isActive, nextSessionDate: record.nextSessionDate, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingExercises = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ExerciseDefinition>()).map { ($0.id, $0) })
        for record in backup.exerciseDefinitions ?? [] { if let value = existingExercises[record.id] { value.name = record.name; value.muscleGroup = record.muscleGroup; value.defaultSets = record.defaultSets; value.defaultReps = record.defaultReps; value.defaultWeight = record.defaultWeight; value.updatedAt = record.updatedAt } else { context.insert(ExerciseDefinition(id: record.id, name: record.name, muscleGroup: record.muscleGroup, defaultSets: record.defaultSets, defaultReps: record.defaultReps, defaultWeight: record.defaultWeight, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingWorkouts = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<WorkoutRecord>()).map { ($0.id, $0) })
        for record in backup.workoutRecords ?? [] { if let value = existingWorkouts[record.id] { value.date = record.date; value.title = record.title; value.durationMinutes = record.durationMinutes; value.note = record.note; value.planID = record.planID; value.updatedAt = record.updatedAt } else { context.insert(WorkoutRecord(id: record.id, date: record.date, title: record.title, durationMinutes: record.durationMinutes, note: record.note, planID: record.planID, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingPlanExercises = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<PlannedWorkoutExercise>()).map { ($0.id, $0) })
        for record in backup.plannedWorkoutExercises ?? [] { if let value = existingPlanExercises[record.id] { value.planID = record.planID; value.exerciseID = record.exerciseID; value.order = record.order; value.targetSets = record.targetSets; value.targetReps = record.targetReps; value.targetWeight = record.targetWeight } else { context.insert(PlannedWorkoutExercise(id: record.id, planID: record.planID, exerciseID: record.exerciseID, order: record.order, targetSets: record.targetSets, targetReps: record.targetReps, targetWeight: record.targetWeight)) } }
        let existingPlannedSessions = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).map { ($0.id, $0) })
        for record in backup.plannedWorkoutSessions ?? [] { if let value = existingPlannedSessions[record.id] { value.planID = record.planID; value.date = record.date; value.isCompleted = record.isCompleted; value.note = record.note; value.updatedAt = record.updatedAt } else { context.insert(PlannedWorkoutSession(id: record.id, planID: record.planID, date: record.date, isCompleted: record.isCompleted, note: record.note, createdAt: record.createdAt, updatedAt: record.updatedAt)) } }
        let existingLogs = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CompletedExerciseLog>()).map { ($0.id, $0) })
        for record in backup.completedExerciseLogs ?? [] { if let value = existingLogs[record.id] { value.sessionID = record.sessionID; value.exerciseID = record.exerciseID; value.sets = record.sets; value.reps = record.reps; value.weight = record.weight; value.note = record.note } else { context.insert(CompletedExerciseLog(id: record.id, sessionID: record.sessionID, exerciseID: record.exerciseID, sets: record.sets, reps: record.reps, weight: record.weight, note: record.note)) } }
        let existingProjects = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<ProjectRecord>()).map { ($0.id, $0) })
        for record in backup.organizationProjects ?? [] {
            if let value = existingProjects[record.id] { value.title = record.title; value.details = record.details; value.dueDate = record.dueDate; value.isArchived = record.isArchived; value.priority = OrganizationPriority(rawValue: record.priority)!; value.status = OrganizationStatus(rawValue: record.status)!; value.updatedAt = record.updatedAt }
            else { context.insert(ProjectRecord(id: record.id, title: record.title, details: record.details, dueDate: record.dueDate, isArchived: record.isArchived, priority: OrganizationPriority(rawValue: record.priority)!, status: OrganizationStatus(rawValue: record.status)!, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingOrganizationTasks = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<OrganizationTask>()).map { ($0.id, $0) })
        for record in backup.organizationTasks ?? [] {
            if let value = existingOrganizationTasks[record.id] { value.projectID = record.projectID; value.parentTaskID = record.parentTaskID; value.title = record.title; value.details = record.details; value.dueDate = record.dueDate; value.priority = OrganizationPriority(rawValue: record.priority)!; value.status = OrganizationStatus(rawValue: record.status)!; value.order = record.order; value.overdueReviewedAt = record.overdueReviewedAt; value.updatedAt = record.updatedAt }
            else { context.insert(OrganizationTask(id: record.id, projectID: record.projectID, parentTaskID: record.parentTaskID, title: record.title, details: record.details, dueDate: record.dueDate, priority: OrganizationPriority(rawValue: record.priority)!, status: OrganizationStatus(rawValue: record.status)!, order: record.order, overdueReviewedAt: record.overdueReviewedAt, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingPlacements = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<PlannedTaskPlacement>()).map { ($0.id, $0) })
        for record in backup.plannedTaskPlacements ?? [] {
            if let value = existingPlacements[record.id] { value.source = TaskPlacementSource(rawValue: record.source)!; value.sourceRecordID = record.sourceRecordID; value.planDate = record.planDate; value.startDate = record.startDate; value.endDate = record.endDate; value.updatedAt = record.updatedAt }
            else { context.insert(PlannedTaskPlacement(id: record.id, source: TaskPlacementSource(rawValue: record.source)!, sourceRecordID: record.sourceRecordID, planDate: record.planDate, startDate: record.startDate, endDate: record.endDate, createdAt: record.createdAt, updatedAt: record.updatedAt)) }
        }
        let existingFocus = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<FocusSessionRecord>()).map { ($0.id, $0) })
        for record in backup.focusSessions ?? [] {
            if let value = existingFocus[record.id] {
                value.title = record.title; value.source = FocusSource(rawValue: record.source)!; value.sourceRecordID = record.sourceRecordID
                value.courseID = record.courseID; value.startedAt = record.startedAt; value.endedAt = record.endedAt
                value.elapsedSeconds = record.elapsedSeconds; value.plannedDurationSeconds = record.plannedDurationSeconds
                value.outcome = FocusOutcome(rawValue: record.outcome)!; value.createdAt = record.createdAt
            } else {
                context.insert(FocusSessionRecord(id: record.id, title: record.title, source: FocusSource(rawValue: record.source)!,
                    sourceRecordID: record.sourceRecordID, courseID: record.courseID, startedAt: record.startedAt,
                    endedAt: record.endedAt, elapsedSeconds: record.elapsedSeconds, plannedDurationSeconds: record.plannedDurationSeconds,
                    outcome: FocusOutcome(rawValue: record.outcome)!, createdAt: record.createdAt))
            }
        }
        try context.save()
    }
}

struct JSONBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
