import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class GymTests: XCTestCase {
    func testSummaryVolumeNextSessionAndPersonalBest() throws {
        let viewModel = GymViewModel(); let now = Date.now; let exerciseID = UUID(); let sessionID = UUID()
        let sessions = [WorkoutRecord(id: sessionID, title: "A", durationMinutes: 50), WorkoutRecord(title: "B", durationMinutes: 40)]
        let logs = [CompletedExerciseLog(sessionID: sessionID, exerciseID: exerciseID, sets: 3, reps: 10, weight: 50), CompletedExerciseLog(sessionID: sessionID, exerciseID: exerciseID, sets: 2, reps: 5, weight: 60)]
        let planned = [PlannedWorkoutSession(date: now.addingTimeInterval(7200)), PlannedWorkoutSession(date: now.addingTimeInterval(3600)), PlannedWorkoutSession(date: now.addingTimeInterval(-3600))]
        let result = viewModel.summary(sessions: sessions, logs: logs, planned: planned, now: now)
        XCTAssertEqual(result.sessionCount, 2); XCTAssertEqual(result.totalMinutes, 90); XCTAssertEqual(result.totalVolume, 2100, accuracy: 0.001)
        XCTAssertEqual(result.nextSession, planned[1].date); XCTAssertEqual(viewModel.personalBest(logs: logs, exerciseID: exerciseID), 60)
    }

    func testGymCRUDLinksAndValidation() throws {
        let container = try PersistenceController.makeContainer(inMemory: true); let context = container.mainContext; let viewModel = GymViewModel()
        try viewModel.savePlan(nil, name: "Güç", goal: "İlerleme", active: true, nextDate: .now, context: context)
        try viewModel.saveExercise(nil, name: "Squat", group: "Bacak", sets: 3, reps: 5, weight: 80, context: context)
        let plan = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutPlan>()).first); let exercise = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciseDefinition>()).first)
        viewModel.activePlansOnly = true
        XCTAssertEqual(viewModel.filteredPlans([plan, WorkoutPlan(name: "Pasif", isActive: false)]).map(\.id), [plan.id])
        try viewModel.saveCompletedSession(nil, title: "Gün A", date: .now, duration: 60, note: "", planID: plan.id, exerciseID: exercise.id, sets: 3, reps: 5, weight: 80, context: context)
        let workout = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutRecord>()).first); let log = try XCTUnwrap(context.fetch(FetchDescriptor<CompletedExerciseLog>()).first)
        XCTAssertEqual(workout.planID, plan.id); XCTAssertEqual(log.sessionID, workout.id); XCTAssertEqual(log.exerciseID, exercise.id)
        XCTAssertThrowsError(try viewModel.saveExercise(nil, name: "", group: "", sets: 0, reps: 0, weight: -1, context: context))
    }

    func testVersionFourBackupRoundTripsGymGraph() throws {
        let source = try PersistenceController.makeContainer(inMemory: true); let context = source.mainContext
        let plan = WorkoutPlan(name: "Program"); let exercise = ExerciseDefinition(name: "Bench"); let workout = WorkoutRecord(title: "Üst", planID: plan.id)
        context.insert(plan); context.insert(exercise); context.insert(workout); context.insert(PlannedWorkoutExercise(planID: plan.id, exerciseID: exercise.id)); context.insert(PlannedWorkoutSession(planID: plan.id)); context.insert(CompletedExerciseLog(sessionID: workout.id, exerciseID: exercise.id, sets: 3, reps: 8, weight: 70)); try context.save()
        let backup = try BackupService.decoded(BackupService.encoded(BackupService.export(from: context)))
        let destination = try PersistenceController.makeContainer(inMemory: true); try BackupService.apply(backup, mode: .replace, to: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<WorkoutPlan>()).count, 1); XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<PlannedWorkoutExercise>()).count, 1); XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<CompletedExerciseLog>()).count, 1)
    }
}
