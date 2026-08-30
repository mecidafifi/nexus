import Foundation
import SwiftData

enum AssessmentKind: String, CaseIterable, Codable, Identifiable {
    case midterm, finalExam, quiz, assignment, project, other
    var id: String { rawValue }
    var titleKey: String { "obs.assessment.kind.\(rawValue)" }
}

@Model
final class UniversityCourse {
    @Attribute(.unique) var id: UUID
    var name: String
    var code: String
    var semester: String
    var creditHours: Double
    var linkedStudyCourseID: UUID?
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, code: String = "", semester: String = "", creditHours: Double = 3, linkedStudyCourseID: UUID? = nil, isActive: Bool = true, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.name = name; self.code = code; self.semester = semester; self.creditHours = creditHours
        self.linkedStudyCourseID = linkedStudyCourseID; self.isActive = isActive; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class OBSAssessment {
    @Attribute(.unique) var id: UUID
    var universityCourseID: UUID
    var title: String
    var kindRaw: String
    var dueDate: Date
    var maximumPoints: Double
    var earnedPoints: Double?
    var weightPercent: Double
    var note: String
    var createdAt: Date
    var updatedAt: Date

    var kind: AssessmentKind {
        get { AssessmentKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), universityCourseID: UUID, title: String, kind: AssessmentKind = .midterm, dueDate: Date = .now, maximumPoints: Double = 100, earnedPoints: Double? = nil, weightPercent: Double = 0, note: String = "", createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.universityCourseID = universityCourseID; self.title = title; self.kindRaw = kind.rawValue
        self.dueDate = dueDate; self.maximumPoints = maximumPoints; self.earnedPoints = earnedPoints; self.weightPercent = weightPercent
        self.note = note; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class GradeScaleBand {
    @Attribute(.unique) var id: UUID
    var letter: String
    var minimumPercent: Double
    var gradePoints: Double
    var createdAt: Date

    init(id: UUID = UUID(), letter: String, minimumPercent: Double, gradePoints: Double, createdAt: Date = .now) {
        self.id = id; self.letter = letter; self.minimumPercent = minimumPercent; self.gradePoints = gradePoints; self.createdAt = createdAt
    }
}
