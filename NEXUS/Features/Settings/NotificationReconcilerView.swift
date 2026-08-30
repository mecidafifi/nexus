import SwiftUI
import SwiftData

/// An invisible query observer. SwiftData query changes after CRUD operations
/// rebuild the transient snapshot and reconcile only NEXUS-owned identifiers.
/// It never requests authorization.
struct NotificationReconcilerView: View {
    @EnvironmentObject private var appState: AppState
    @Query private var courses: [Course]
    @Query private var rules: [StudyScheduleRule]
    @Query private var attendance: [AttendanceRecord]
    @Query private var studyTasks: [StudyTask]
    @Query private var organizationTasks: [OrganizationTask]
    @Query private var calendarEntries: [CalendarEntry]
    @Query private var assessments: [OBSAssessment]
    @Query private var placements: [PlannedTaskPlacement]
    @Query private var plannedWorkouts: [PlannedWorkoutSession]

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: fingerprint) { await reconcile() }
            .onReceive(NotificationCenter.default.publisher(for: .nexusNotificationSettingsChanged)) { _ in
                Task { await reconcile() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nexusNotificationRescheduleRequested)) { _ in
                Task { await reconcile() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .nexusNotificationEnableRequested)) { _ in
                Task {
                    var preferences = LocalNotificationPreferences.current()
                    if appState.appLock.isEnabled { preferences.hideDetails = true }
                    await appState.notificationService.enableFromExplicitUserAction(
                        snapshot: snapshot(now: .now), preferences: preferences
                    )
                }
            }
    }

    private var fingerprint: String {
        let parts = [
            courses.map { "c:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            rules.map { "r:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            attendance.map { "a:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            studyTasks.map { "s:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            organizationTasks.map { "o:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            calendarEntries.map { "e:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            assessments.map { "x:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            placements.map { "p:\($0.id):\($0.updatedAt.timeIntervalSince1970)" },
            plannedWorkouts.map { "w:\($0.id):\($0.updatedAt.timeIntervalSince1970)" }
        ].flatMap { $0 }.sorted()
        return parts.joined(separator: "|")
    }

    private func reconcile() async {
        var preferences = LocalNotificationPreferences.current()
        if appState.appLock.isEnabled { preferences.hideDetails = true }
        await appState.notificationService.reconcile(snapshot: snapshot(now: .now), preferences: preferences)
    }

    private func snapshot(now: Date, calendar: Calendar = .current) -> NotificationPlanningSnapshot {
        let days = (0..<15).compactMap { calendar.date(byAdding: .day, value: $0, to: calendar.startOfDay(for: now)) }
        let cancelled = Set(attendance.filter { $0.status == .cancelled }.map(\.occurrenceID))
        let occurrences = days.flatMap { DailyPlanAggregator.occurrences(rules: rules, on: $0, courses: courses, calendar: calendar) }
            .filter { $0.start > now && !cancelled.contains($0.id) }
        let lessons = occurrences.map {
            NotificationLessonSource(occurrenceID: $0.id, courseID: $0.courseID, title: $0.title, start: $0.start, end: $0.end)
        }

        var deadlines: [NotificationDeadlineSource] = studyTasks.compactMap { task in
            task.dueDate.map { NotificationDeadlineSource(id: "study-\(task.id)", title: task.title, dueDate: $0, isCompleted: task.status == .completed) }
        }
        deadlines += organizationTasks.compactMap { task in
            task.dueDate.map { NotificationDeadlineSource(id: "organization-\(task.id)", title: task.title, dueDate: $0, isCompleted: task.status == .completed || task.status == .cancelled) }
        }
        deadlines += calendarEntries.filter { $0.kind != .event }.map {
            NotificationDeadlineSource(id: "calendar-\($0.id)", title: $0.title, dueDate: $0.reminderDate ?? $0.startDate, isCompleted: $0.isCompleted)
        }
        deadlines += assessments.map {
            NotificationDeadlineSource(id: "assessment-\($0.id)", title: $0.title, dueDate: $0.dueDate, isCompleted: $0.earnedPoints != nil)
        }

        let risks = courses.compactMap { course -> NotificationAttendanceRiskSource? in
            let absent = attendance.filter { $0.courseID == course.id && $0.status == .absent }.count
            guard let next = occurrences.first(where: { $0.courseID == course.id }) else { return nil }
            return NotificationAttendanceRiskSource(
                courseID: course.id, courseTitle: course.name, absentCount: absent,
                allowedAbsenceCount: max(course.allowedAbsenceCount, 0), nextLessonStart: next.start
            )
        }

        struct Fixed { let id: String; let start: Date; let end: Date }
        var fixed = occurrences.map { Fixed(id: $0.id, start: $0.start, end: $0.end) }
        fixed += calendarEntries.filter { !$0.isAllDay && $0.endDate > now }.map { Fixed(id: "calendar-\($0.id)", start: $0.startDate, end: $0.endDate) }
        fixed += placements.filter { $0.endDate > now }.map { Fixed(id: "placement-\($0.id)", start: $0.startDate, end: $0.endDate) }
        fixed += plannedWorkouts.filter { $0.date > now }.compactMap { workout in
            calendar.date(byAdding: .minute, value: 60, to: workout.date).map { Fixed(id: "workout-\(workout.id)", start: workout.date, end: $0) }
        }
        var conflicts: [NotificationConflictSource] = []
        for leftIndex in fixed.indices {
            for rightIndex in fixed.indices where rightIndex > leftIndex {
                let left = fixed[leftIndex], right = fixed[rightIndex]
                let overlapStart = max(left.start, right.start)
                if overlapStart < min(left.end, right.end), overlapStart > now {
                    conflicts.append(NotificationConflictSource(leftID: left.id, rightID: right.id, start: overlapStart))
                }
            }
        }
        return NotificationPlanningSnapshot(lessons: lessons, deadlines: deadlines, attendanceRisks: risks, conflicts: conflicts)
    }
}
