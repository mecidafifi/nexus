import Foundation
import SwiftData

struct GymSummary: Equatable {
    let sessionCount: Int
    let totalMinutes: Int
    let totalVolume: Double
    let nextSession: Date?
}
enum GymSection: String, CaseIterable, Identifiable { case overview, plans, exercises, schedule, history; var id: String { rawValue }; var titleKey: String { "gym.section.\(rawValue)" } }
enum GymSort: String, CaseIterable, Identifiable { case newest, oldest, name; var id: String { rawValue }; var titleKey: String { "gym.sort.\(rawValue)" } }

@MainActor
final class GymViewModel: ObservableObject {
    @Published var section: GymSection = .overview
    @Published var searchText = ""
    @Published var sort: GymSort = .newest
    @Published var activePlansOnly = false
    @Published var incompleteScheduleOnly = false
    @Published var errorMessage: String?
    @Published var statusMessageKey = "status.ready"

    func summary(sessions: [WorkoutRecord], logs: [CompletedExerciseLog], planned: [PlannedWorkoutSession], now: Date = .now) -> GymSummary {
        let volume = logs.reduce(0) { $0 + Double($1.sets * $1.reps) * $1.weight }
        let next = planned.filter { !$0.isCompleted && $0.date >= now }.map(\.date).min()
        return GymSummary(sessionCount: sessions.count, totalMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }, totalVolume: volume, nextSession: next)
    }
    func personalBest(logs: [CompletedExerciseLog], exerciseID: UUID) -> Double { logs.filter { $0.exerciseID == exerciseID }.map(\.weight).max() ?? 0 }
    func filteredSessions(_ sessions: [WorkoutRecord]) -> [WorkoutRecord] { sessions.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) || $0.note.localizedCaseInsensitiveContains(searchText) }.sorted { lhs, rhs in switch sort { case .newest: lhs.date > rhs.date; case .oldest: lhs.date < rhs.date; case .name: lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending } } }
    func filteredPlans(_ plans: [WorkoutPlan]) -> [WorkoutPlan] { plans.filter { (!activePlansOnly || $0.isActive) && (searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.goal.localizedCaseInsensitiveContains(searchText)) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
    func filteredExercises(_ exercises: [ExerciseDefinition]) -> [ExerciseDefinition] { exercises.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) || $0.muscleGroup.localizedCaseInsensitiveContains(searchText) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }

    func savePlan(_ plan: WorkoutPlan?, name: String, goal: String, active: Bool, nextDate: Date?, context: ModelContext) throws { guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GymValidationError.nameRequired }; if let plan { plan.name = name; plan.goal = goal; plan.isActive = active; plan.nextSessionDate = nextDate; plan.updatedAt = .now } else { context.insert(WorkoutPlan(name: name, goal: goal, isActive: active, nextSessionDate: nextDate)) }; try commit(context) }
    func saveExercise(_ exercise: ExerciseDefinition?, name: String, group: String, sets: Int, reps: Int, weight: Double, context: ModelContext) throws { guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GymValidationError.nameRequired }; guard sets > 0, reps > 0, weight >= 0, weight.isFinite else { throw GymValidationError.invalidExercise }; if let exercise { exercise.name = name; exercise.muscleGroup = group; exercise.defaultSets = sets; exercise.defaultReps = reps; exercise.defaultWeight = weight; exercise.updatedAt = .now } else { context.insert(ExerciseDefinition(name: name, muscleGroup: group, defaultSets: sets, defaultReps: reps, defaultWeight: weight)) }; try commit(context) }
    func savePlannedSession(_ session: PlannedWorkoutSession?, planID: UUID?, date: Date, completed: Bool, note: String, context: ModelContext) throws { if let session { session.planID = planID; session.date = date; session.isCompleted = completed; session.note = note; session.updatedAt = .now } else { context.insert(PlannedWorkoutSession(planID: planID, date: date, isCompleted: completed, note: note)) }; try commit(context) }
    func saveCompletedSession(_ session: WorkoutRecord?, title: String, date: Date, duration: Int, note: String, planID: UUID?, exerciseID: UUID?, sets: Int, reps: Int, weight: Double, context: ModelContext) throws { guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GymValidationError.nameRequired }; guard duration > 0 else { throw GymValidationError.invalidDuration }; guard sets > 0, reps > 0, weight >= 0, weight.isFinite else { throw GymValidationError.invalidExercise }; let target: WorkoutRecord; if let session { target = session; session.title = title; session.date = date; session.durationMinutes = duration; session.note = note; session.planID = planID; session.updatedAt = .now } else { target = WorkoutRecord(date: date, title: title, durationMinutes: duration, note: note, planID: planID); context.insert(target) }; if let exerciseID { context.insert(CompletedExerciseLog(sessionID: target.id, exerciseID: exerciseID, sets: sets, reps: reps, weight: weight)) }; try commit(context) }
    func delete<T: PersistentModel>(_ model: T, context: ModelContext) throws { context.delete(model); try commit(context) }
    private func commit(_ context: ModelContext) throws { do { try context.save(); errorMessage = nil; statusMessageKey = "status.saved" } catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error } }
}
enum GymValidationError: LocalizedError { case nameRequired, invalidExercise, invalidDuration; var errorDescription: String? { switch self { case .nameRequired: String(localized: "gym.validation.name"); case .invalidExercise: String(localized: "gym.validation.exercise"); case .invalidDuration: String(localized: "gym.validation.duration") } } }
