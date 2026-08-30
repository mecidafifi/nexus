import SwiftData

@MainActor
enum CourseDeletionService {
    static func delete(_ course: Course, context: ModelContext) throws {
        let courseID = course.id
        try context.fetch(FetchDescriptor<Lecture>()).filter { $0.courseID == courseID }.forEach { $0.courseID = nil }
        try context.fetch(FetchDescriptor<StudyDocument>()).filter { $0.courseID == courseID }.forEach { $0.courseID = nil }
        try context.fetch(FetchDescriptor<StudyNote>()).filter { $0.courseID == courseID }.forEach { $0.courseID = nil }
        try context.fetch(FetchDescriptor<StudyTask>()).filter { $0.courseID == courseID }.forEach { $0.courseID = nil }
        try context.fetch(FetchDescriptor<CourseScheduleRule>()).filter { $0.courseID == courseID }.forEach(context.delete)
        context.delete(course)
        try context.save()
    }
}
