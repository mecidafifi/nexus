import Foundation
import SwiftData

struct FocusRequest: Identifiable, Equatable {
    let id: UUID
    let source: FocusSource
    let sourceRecordID: UUID?
    let courseID: UUID?
    let title: String
    let plannedDurationSeconds: Int?

    init(id: UUID = UUID(), source: FocusSource, sourceRecordID: UUID? = nil, courseID: UUID? = nil,
         title: String, plannedDurationSeconds: Int? = nil) {
        self.id = id; self.source = source; self.sourceRecordID = sourceRecordID; self.courseID = courseID
        self.title = title; self.plannedDurationSeconds = plannedDurationSeconds.map { max($0, 1) }
    }
}

struct FocusClockState: Equatable {
    let request: FocusRequest
    let startedAt: Date
    private(set) var accumulatedSeconds: TimeInterval
    private(set) var runningSinceUptime: TimeInterval?

    init(request: FocusRequest, startedAt: Date, uptime: TimeInterval) {
        self.request = request; self.startedAt = startedAt; self.accumulatedSeconds = 0; self.runningSinceUptime = uptime
    }

    var isPaused: Bool { runningSinceUptime == nil }

    func elapsedSeconds(at uptime: TimeInterval) -> Int {
        let current = runningSinceUptime.map { max(uptime - $0, 0) } ?? 0
        return max(Int((accumulatedSeconds + current).rounded(.down)), 0)
    }

    mutating func pause(at uptime: TimeInterval) {
        guard let runningSinceUptime else { return }
        accumulatedSeconds += max(uptime - runningSinceUptime, 0)
        self.runningSinceUptime = nil
    }

    mutating func resume(at uptime: TimeInterval) {
        guard runningSinceUptime == nil else { return }
        runningSinceUptime = uptime
    }
}

struct FocusFinishSnapshot: Equatable {
    let request: FocusRequest
    let startedAt: Date
    let endedAt: Date
    let elapsedSeconds: Int
    let outcome: FocusOutcome
}

enum FocusFinishReadiness: Equatable { case noElapsedTime, shortSession, ready }

@MainActor
final class FocusSessionController: ObservableObject {
    @Published private(set) var state: FocusClockState?

    var hasActiveSession: Bool { state != nil }

    @discardableResult
    func begin(_ request: FocusRequest, now: Date = .now, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard state == nil else { return false }
        state = FocusClockState(request: request, startedAt: now, uptime: uptime)
        return true
    }

    func pause(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) { state?.pause(at: uptime) }
    func resume(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) { state?.resume(at: uptime) }
    func elapsedSeconds(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Int { state?.elapsedSeconds(at: uptime) ?? 0 }

    func readiness(uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> FocusFinishReadiness {
        let seconds = elapsedSeconds(uptime: uptime)
        if seconds == 0 { return .noElapsedTime }
        if seconds < 10 { return .shortSession }
        return .ready
    }

    func snapshot(outcome: FocusOutcome, endedAt: Date = .now,
                  uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> FocusFinishSnapshot? {
        guard var state else { return nil }
        state.pause(at: uptime)
        let seconds = state.elapsedSeconds(at: uptime)
        guard seconds > 0 else { return nil }
        return .init(request: state.request, startedAt: state.startedAt, endedAt: endedAt,
                     elapsedSeconds: seconds, outcome: outcome)
    }

    func clear() { state = nil }
}

enum FocusPersistenceError: LocalizedError {
    case invalidDuration, missingSource, sourceNotCompletable
    var errorDescription: String? {
        switch self {
        case .invalidDuration: String(localized: "focus.error.duration")
        case .missingSource: String(localized: "focus.error.sourceMissing")
        case .sourceNotCompletable: String(localized: "focus.error.sourceNotCompletable")
        }
    }
}

@MainActor
enum FocusPersistenceService {
    @discardableResult
    static func save(
        _ snapshot: FocusFinishSnapshot, studyTasks: [StudyTask], organizationTasks: [OrganizationTask],
        calendarEntries: [CalendarEntry], context: ModelContext, now: Date = .now
    ) throws -> FocusSessionRecord {
        guard snapshot.elapsedSeconds > 0, snapshot.endedAt >= snapshot.startedAt else { throw FocusPersistenceError.invalidDuration }

        if snapshot.outcome == .completed {
            switch snapshot.request.source {
            case .studyTask:
                guard let task = studyTasks.first(where: { $0.id == snapshot.request.sourceRecordID }) else { throw FocusPersistenceError.missingSource }
                guard task.status != .cancelled else { throw FocusPersistenceError.sourceNotCompletable }
            case .organizationTask:
                guard let task = organizationTasks.first(where: { $0.id == snapshot.request.sourceRecordID }) else { throw FocusPersistenceError.missingSource }
                guard task.status != .cancelled else { throw FocusPersistenceError.sourceNotCompletable }
            case .calendarTask:
                guard let entry = calendarEntries.first(where: { $0.id == snapshot.request.sourceRecordID }) else { throw FocusPersistenceError.missingSource }
                guard entry.kind != .event else { throw FocusPersistenceError.sourceNotCompletable }
            case .studyContext: break
            }
        }

        let record = FocusSessionRecord(title: snapshot.request.title, source: snapshot.request.source,
            sourceRecordID: snapshot.request.sourceRecordID, courseID: snapshot.request.courseID,
            startedAt: snapshot.startedAt, endedAt: snapshot.endedAt, elapsedSeconds: snapshot.elapsedSeconds,
            plannedDurationSeconds: snapshot.request.plannedDurationSeconds, outcome: snapshot.outcome, createdAt: now)
        context.insert(record)

        if snapshot.outcome == .completed {
            switch snapshot.request.source {
            case .studyTask:
                if let task = studyTasks.first(where: { $0.id == snapshot.request.sourceRecordID }) {
                    task.status = .completed; task.completedAt = snapshot.endedAt; task.updatedAt = now
                }
            case .organizationTask:
                if let task = organizationTasks.first(where: { $0.id == snapshot.request.sourceRecordID }) {
                    task.status = .completed; task.updatedAt = now
                }
            case .calendarTask:
                if let entry = calendarEntries.first(where: { $0.id == snapshot.request.sourceRecordID }) {
                    entry.isCompleted = true; entry.updatedAt = now
                }
            case .studyContext: break
            }
        }
        try context.save()
        return record
    }
}
