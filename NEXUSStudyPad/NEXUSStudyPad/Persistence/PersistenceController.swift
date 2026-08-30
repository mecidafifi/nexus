import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Course.self, Lecture.self, StudyDocument.self, PDFInkLayer.self,
        StudyNote.self, StudyTask.self, AudioRecording.self, CourseScheduleRule.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
