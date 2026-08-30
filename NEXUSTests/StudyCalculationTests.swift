import XCTest
@testable import NEXUS

@MainActor
final class StudyCalculationTests: XCTestCase {
    func testTaskCompletionRatio() {
        let viewModel = StudyViewModel()
        let tasks = [StudyTask(title: "A", status: .completed), StudyTask(title: "B", status: .planned), StudyTask(title: "C", status: .completed)]
        XCTAssertEqual(viewModel.completedTaskRatio(tasks), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(viewModel.completedTaskRatio([]), 0)
    }

    func testGoalProgressUsesDateAndCourseScopeAndCapsAtOne() {
        let viewModel = StudyViewModel()
        let courseID = UUID()
        let now = Date.now
        let goal = StudyGoal(title: "Hedef", courseID: courseID, targetMinutes: 60, startDate: now.addingTimeInterval(-3600), endDate: now.addingTimeInterval(3600))
        let matching = StudySession(courseID: courseID, startedAt: now, durationMinutes: 75)
        let otherCourse = StudySession(courseID: UUID(), startedAt: now, durationMinutes: 200)
        let outsideRange = StudySession(courseID: courseID, startedAt: now.addingTimeInterval(-7200), durationMinutes: 200)
        XCTAssertEqual(viewModel.goalProgress(goal, sessions: [matching, otherCourse, outsideRange]), 1)
    }

    func testTaskFilteringAndPrioritySort() {
        let viewModel = StudyViewModel()
        viewModel.searchText = "rapor"
        viewModel.taskStatusFilter = .planned
        viewModel.sort = .priority
        let low = StudyTask(title: "Rapor taslağı", status: .planned, priority: .low)
        let high = StudyTask(title: "Rapor final", status: .planned, priority: .critical)
        let excluded = StudyTask(title: "Rapor eski", status: .completed, priority: .critical)
        XCTAssertEqual(viewModel.filteredTasks([low, excluded, high]).map(\.id), [high.id, low.id])
    }
}
