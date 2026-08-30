import Foundation
import SwiftData

enum FocusSource: String, CaseIterable, Codable {
    case studyTask, organizationTask, calendarTask, studyContext

    var countsAsStudyTime: Bool { self == .studyTask || self == .studyContext }
}

enum FocusOutcome: String, CaseIterable, Codable {
    case completed, stopped
}

/// An immutable history row created only when the user explicitly completes or
/// stops a Focus Mode session. The source title is retained so history remains
/// understandable even if the owning task is later deleted.
@Model
final class FocusSessionRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var sourceRaw: String
    var sourceRecordID: UUID?
    var courseID: UUID?
    var startedAt: Date
    var endedAt: Date
    var elapsedSeconds: Int
    var plannedDurationSeconds: Int?
    var outcomeRaw: String
    var createdAt: Date

    var source: FocusSource {
        get { FocusSource(rawValue: sourceRaw) ?? .studyContext }
        set { sourceRaw = newValue.rawValue }
    }
    var outcome: FocusOutcome {
        get { FocusOutcome(rawValue: outcomeRaw) ?? .stopped }
        set { outcomeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(), title: String, source: FocusSource, sourceRecordID: UUID? = nil,
        courseID: UUID? = nil, startedAt: Date, endedAt: Date, elapsedSeconds: Int,
        plannedDurationSeconds: Int? = nil, outcome: FocusOutcome, createdAt: Date = .now
    ) {
        self.id = id; self.title = title; self.sourceRaw = source.rawValue; self.sourceRecordID = sourceRecordID
        self.courseID = courseID; self.startedAt = startedAt; self.endedAt = endedAt
        self.elapsedSeconds = max(elapsedSeconds, 0); self.plannedDurationSeconds = plannedDurationSeconds
        self.outcomeRaw = outcome.rawValue; self.createdAt = createdAt
    }
}
