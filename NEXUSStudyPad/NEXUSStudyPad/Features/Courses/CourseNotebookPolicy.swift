import Foundation

enum CourseNotebookPolicy {
    static let defaultSemesterWeekCount = 15
    static let maximumSemesterWeekCount = 30
    static let maximumLessonsPerWeek = 10

    static func lectures(for courseID: UUID, week: Int, from lectures: [Lecture]) -> [Lecture] {
        lectures
            .filter { $0.courseID == courseID && $0.weekNumber == week }
            .sorted {
                if $0.lessonNumber != $1.lessonNumber { return $0.lessonNumber < $1.lessonNumber }
                return $0.date < $1.date
            }
    }

    static func nextLessonNumber(for courseID: UUID, week: Int, from lectures: [Lecture]) -> Int {
        min((self.lectures(for: courseID, week: week, from: lectures).map(\.lessonNumber).max() ?? 0) + 1, maximumLessonsPerWeek)
    }

    static func hasDuplicate(courseID: UUID?, week: Int, lesson: Int, excluding lectureID: UUID?, in lectures: [Lecture]) -> Bool {
        lectures.contains {
            $0.id != lectureID && $0.courseID == courseID && $0.weekNumber == week && $0.lessonNumber == lesson
        }
    }
}
