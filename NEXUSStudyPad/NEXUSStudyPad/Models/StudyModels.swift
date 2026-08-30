import Foundation
import SwiftData

enum LectureAttendance: String, Codable, CaseIterable, Identifiable {
    case unmarked, present, absent, excused
    var id: String { rawValue }
    var title: String {
        switch self {
        case .unmarked: "İşaretlenmedi"
        case .present: "Katıldı"
        case .absent: "Katılmadı"
        case .excused: "Mazeretli"
        }
    }
}

enum LectureReviewStatus: String, Codable, CaseIterable, Identifiable {
    case notReviewed, inProgress, reviewed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notReviewed: "İncelenmedi"
        case .inProgress: "İnceleniyor"
        case .reviewed: "İncelendi"
        }
    }
}

enum StudyNoteKind: String, Codable, CaseIterable, Identifiable {
    case markdown, handwritten
    var id: String { rawValue }
    var title: String { self == .markdown ? "Metin / Markdown" : "El yazısı" }
}

@Model
final class Course {
    @Attribute(.unique) var id: UUID
    var name: String
    var code: String
    var instructor: String
    var semesterWeekCount: Int = 15
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, code: String = "", instructor: String = "", semesterWeekCount: Int = 15, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.code = code.trimmingCharacters(in: .whitespacesAndNewlines)
        self.instructor = instructor.trimmingCharacters(in: .whitespacesAndNewlines)
        self.semesterWeekCount = min(max(semesterWeekCount, 1), 30)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func validationError(name: String) -> String? {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ders adı gereklidir." : nil
    }
}

@Model
final class Lecture {
    @Attribute(.unique) var id: UUID
    var courseID: UUID?
    var title: String
    var date: Date
    var attendanceRaw: String
    var reviewRaw: String
    var note: String
    var weekNumber: Int = 1
    var lessonNumber: Int = 1
    var createdAt: Date
    var updatedAt: Date

    var attendance: LectureAttendance {
        get { LectureAttendance(rawValue: attendanceRaw) ?? .unmarked }
        set { attendanceRaw = newValue.rawValue; updatedAt = .now }
    }
    var reviewStatus: LectureReviewStatus {
        get { LectureReviewStatus(rawValue: reviewRaw) ?? .notReviewed }
        set { reviewRaw = newValue.rawValue; updatedAt = .now }
    }

    init(id: UUID = UUID(), courseID: UUID?, title: String, date: Date, attendance: LectureAttendance = .unmarked, reviewStatus: LectureReviewStatus = .notReviewed, note: String = "", weekNumber: Int = 1, lessonNumber: Int = 1, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.date = date; self.attendanceRaw = attendance.rawValue; self.reviewRaw = reviewStatus.rawValue
        self.note = note; self.weekNumber = max(weekNumber, 1); self.lessonNumber = max(lessonNumber, 1)
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    static func validationError(title: String, courseID: UUID?, weekNumber: Int = 1, lessonNumber: Int = 1, semesterWeekCount: Int = 30) -> String? {
        if courseID == nil { return "Bir ders seçin." }
        if !(1...max(semesterWeekCount, 1)).contains(weekNumber) { return "Hafta numarası dersin dönem aralığında olmalıdır." }
        if !(1...10).contains(lessonNumber) { return "Ders numarası 1 ile 10 arasında olmalıdır." }
        return title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ders oturumu başlığı gereklidir." : nil
    }
}

@Model
final class StudyDocument {
    @Attribute(.unique) var id: UUID
    var courseID: UUID?
    var lectureID: UUID?
    var title: String
    var storedFileName: String
    var importedAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), courseID: UUID? = nil, lectureID: UUID? = nil, title: String, storedFileName: String, importedAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID; self.lectureID = lectureID
        self.title = title; self.storedFileName = storedFileName
        self.importedAt = importedAt; self.updatedAt = updatedAt
    }
}

@Model
final class PDFInkLayer {
    @Attribute(.unique) var id: UUID
    var documentID: UUID
    var pageIndex: Int
    @Attribute(.externalStorage) var drawingData: Data
    var updatedAt: Date

    init(id: UUID = UUID(), documentID: UUID, pageIndex: Int, drawingData: Data, updatedAt: Date = .now) {
        self.id = id; self.documentID = documentID; self.pageIndex = pageIndex
        self.drawingData = drawingData; self.updatedAt = updatedAt
    }
}

@Model
final class StudyNote {
    @Attribute(.unique) var id: UUID
    var courseID: UUID?
    var lectureID: UUID?
    var title: String
    var body: String
    var kindRaw: String
    @Attribute(.externalStorage) var drawingData: Data?
    var isPinned: Bool
    var createdAt: Date
    var updatedAt: Date

    var kind: StudyNoteKind {
        get { StudyNoteKind(rawValue: kindRaw) ?? .markdown }
        set { kindRaw = newValue.rawValue; updatedAt = .now }
    }

    init(id: UUID = UUID(), courseID: UUID? = nil, lectureID: UUID? = nil, title: String, body: String = "", kind: StudyNoteKind = .markdown, drawingData: Data? = nil, isPinned: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID; self.lectureID = lectureID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines); self.body = body
        self.kindRaw = kind.rawValue; self.drawingData = drawingData; self.isPinned = isPinned
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    static func validationError(title: String) -> String? {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not başlığı gereklidir." : nil
    }
}

@Model
final class StudyTask {
    @Attribute(.unique) var id: UUID
    var courseID: UUID?
    var title: String
    var details: String
    var dueDate: Date?
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), courseID: UUID? = nil, title: String, details: String = "", dueDate: Date? = nil, isCompleted: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines); self.details = details
        self.dueDate = dueDate; self.isCompleted = isCompleted
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    static func validationError(title: String) -> String? {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Görev başlığı gereklidir." : nil
    }
}

@Model
final class AudioRecording {
    @Attribute(.unique) var id: UUID
    var lectureID: UUID
    var title: String
    var storedFileName: String
    var durationSeconds: Double
    var createdAt: Date

    init(id: UUID = UUID(), lectureID: UUID, title: String, storedFileName: String, durationSeconds: Double, createdAt: Date = .now) {
        self.id = id; self.lectureID = lectureID; self.title = title
        self.storedFileName = storedFileName; self.durationSeconds = durationSeconds; self.createdAt = createdAt
    }
}

@Model
final class CourseScheduleRule {
    @Attribute(.unique) var id: UUID
    var courseID: UUID
    var weekday: Int
    var startMinutes: Int
    var durationMinutes: Int
    var effectiveStart: Date
    var effectiveEnd: Date?
    var location: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), courseID: UUID, weekday: Int, startMinutes: Int, durationMinutes: Int = 50, effectiveStart: Date = .now, effectiveEnd: Date? = nil, location: String = "", isActive: Bool = true, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID
        self.weekday = weekday; self.startMinutes = startMinutes; self.durationMinutes = durationMinutes
        self.effectiveStart = effectiveStart; self.effectiveEnd = effectiveEnd
        self.location = location; self.isActive = isActive
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }

    static func isValid(weekday: Int, startMinutes: Int, durationMinutes: Int, effectiveStart: Date, effectiveEnd: Date?) -> Bool {
        (1...7).contains(weekday) && (0...1_439).contains(startMinutes) && (10...720).contains(durationMinutes)
            && (effectiveEnd == nil || effectiveEnd! >= effectiveStart)
    }
}
