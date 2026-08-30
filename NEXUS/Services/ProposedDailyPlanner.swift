import Foundation
import SwiftData

struct DailyPlannerSettings: Equatable {
    var workStartMinutes: Int = 8 * 60
    var workEndMinutes: Int = 20 * 60
    var bufferMinutes: Int = 10
    var defaultTaskDurationMinutes: Int = 45

    var normalized: DailyPlannerSettings {
        DailyPlannerSettings(
            workStartMinutes: min(max(workStartMinutes, 0), 1_380),
            workEndMinutes: min(max(workEndMinutes, workStartMinutes + 30), 1_440),
            bufferMinutes: min(max(bufferMinutes, 0), 120),
            defaultTaskDurationMinutes: min(max(defaultTaskDurationMinutes, 10), 360)
        )
    }
}

struct PlannerFixedItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
}

struct PlannerCandidate: Identifiable, Equatable {
    var id: String { "\(source.rawValue):\(recordID.uuidString.lowercased())" }
    let source: TaskPlacementSource
    let recordID: UUID
    let title: String
    let durationMinutes: Int
    let dueDate: Date?
    /// Larger values are planned first.
    let priorityRank: Int
}

struct ProposedTaskPlacement: Identifiable, Equatable {
    var id: String { candidate.id }
    let candidate: PlannerCandidate
    var start: Date
    var end: Date
}

struct UnplacedPlannerItem: Identifiable, Equatable {
    var id: String { candidate.id }
    let candidate: PlannerCandidate
    let reasonKey: String
}

struct ProposedDailyPlan: Equatable {
    let date: Date
    var placements: [ProposedTaskPlacement]
    let unplaced: [UnplacedPlannerItem]
    let fixedConflictCount: Int

    var hasOverload: Bool { !unplaced.isEmpty }
}

enum ProposedDailyPlanner {
    static func generate(date: Date, fixed: [PlannerFixedItem], candidates: [PlannerCandidate],
                         settings rawSettings: DailyPlannerSettings, calendar: Calendar = .current) -> ProposedDailyPlan {
        let settings = rawSettings.normalized
        let day = calendar.startOfDay(for: date)
        guard let workStart = calendar.date(byAdding: .minute, value: settings.workStartMinutes, to: day),
              let workEnd = calendar.date(byAdding: .minute, value: settings.workEndMinutes, to: day) else {
            return ProposedDailyPlan(date: day, placements: [], unplaced: candidates.map { .init(candidate: $0, reasonKey: "planner.unplaced.invalidDay") }, fixedConflictCount: 0)
        }

        let validFixed = fixed.filter { $0.end > $0.start && $0.end > workStart && $0.start < workEnd }
            .sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
        let conflictCount = overlappingPairCount(validFixed)
        let buffer = TimeInterval(settings.bufferMinutes * 60)
        var occupied = validFixed.map {
            DateInterval(start: max(workStart, $0.start.addingTimeInterval(-buffer)),
                         end: min(workEnd, $0.end.addingTimeInterval(buffer)))
        }
        occupied = merge(occupied)

        let sortedCandidates = candidates.sorted(by: candidatePrecedes)
        var placements: [ProposedTaskPlacement] = []
        var unplaced: [UnplacedPlannerItem] = []

        for candidate in sortedCandidates {
            let minutes = min(max(candidate.durationMinutes, 10), 720)
            let duration = TimeInterval(minutes * 60)
            guard let start = firstAvailableStart(duration: duration, workStart: workStart, workEnd: workEnd, occupied: occupied) else {
                unplaced.append(.init(candidate: candidate, reasonKey: "planner.unplaced.noRoom"))
                continue
            }
            let end = start.addingTimeInterval(duration)
            placements.append(.init(candidate: candidate, start: start, end: end))
            occupied.append(DateInterval(start: max(workStart, start.addingTimeInterval(-buffer)),
                                         end: min(workEnd, end.addingTimeInterval(buffer))))
            occupied = merge(occupied)
        }

        return ProposedDailyPlan(date: day, placements: placements.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start },
                                 unplaced: unplaced, fixedConflictCount: conflictCount)
    }

    static func placementsAreValid(_ placements: [ProposedTaskPlacement], fixed: [PlannerFixedItem],
                                   date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        guard Set(placements.map(\.id)).count == placements.count,
              placements.allSatisfy({ $0.end > $0.start && calendar.isDate($0.start, inSameDayAs: day) && calendar.isDate($0.end.addingTimeInterval(-1), inSameDayAs: day) }) else { return false }
        let intervals = placements.map { DateInterval(start: $0.start, end: $0.end) }
        for left in intervals.indices {
            for right in intervals.indices where right > left {
                if intervals[left].intersects(intervals[right]) { return false }
            }
        }
        return !placements.contains { placement in fixed.contains { $0.end > $0.start && placement.start < $0.end && $0.start < placement.end } }
    }

    private static func candidatePrecedes(_ left: PlannerCandidate, _ right: PlannerCandidate) -> Bool {
        if left.priorityRank != right.priorityRank { return left.priorityRank > right.priorityRank }
        switch (left.dueDate, right.dueDate) {
        case let (lhs?, rhs?) where lhs != rhs: return lhs < rhs
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        let titleOrder = left.title.localizedStandardCompare(right.title)
        if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
        if left.source.rawValue != right.source.rawValue { return left.source.rawValue < right.source.rawValue }
        return left.recordID.uuidString < right.recordID.uuidString
    }

    private static func firstAvailableStart(duration: TimeInterval, workStart: Date, workEnd: Date,
                                            occupied: [DateInterval]) -> Date? {
        var cursor = workStart
        for interval in occupied {
            if cursor.addingTimeInterval(duration) <= interval.start { return cursor }
            if interval.end > cursor { cursor = interval.end }
        }
        return cursor.addingTimeInterval(duration) <= workEnd ? cursor : nil
    }

    private static func merge(_ intervals: [DateInterval]) -> [DateInterval] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var output: [DateInterval] = []
        for interval in sorted {
            guard let last = output.last, interval.start <= last.end else { output.append(interval); continue }
            output[output.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
        }
        return output
    }

    private static func overlappingPairCount(_ fixed: [PlannerFixedItem]) -> Int {
        var count = 0
        for left in fixed.indices {
            for right in fixed.indices where right > left {
                if fixed[left].start < fixed[right].end && fixed[right].start < fixed[left].end { count += 1 }
            }
        }
        return count
    }
}

enum PlannerAcceptanceError: Error, LocalizedError {
    case invalidPlacement, missingSource
    var errorDescription: String? {
        switch self {
        case .invalidPlacement: String(localized: "planner.error.invalidPlacement")
        case .missingSource: String(localized: "planner.error.missingSource")
        }
    }
}

@MainActor
enum PlannerAcceptanceService {
    static func accept(_ placements: [ProposedTaskPlacement], fixed: [PlannerFixedItem], date: Date,
                       existing: [PlannedTaskPlacement], context: ModelContext, calendar: Calendar = .current,
                       now: Date = .now) throws {
        guard ProposedDailyPlanner.placementsAreValid(placements, fixed: fixed, date: date, calendar: calendar) else {
            throw PlannerAcceptanceError.invalidPlacement
        }
        let studyIDs = Set(try context.fetch(FetchDescriptor<StudyTask>()).map(\.id))
        let organizationIDs = Set(try context.fetch(FetchDescriptor<OrganizationTask>()).map(\.id))
        let calendarIDs = Set(try context.fetch(FetchDescriptor<CalendarEntry>()).map(\.id))
        for proposal in placements {
            let exists: Bool
            switch proposal.candidate.source {
            case .studyTask: exists = studyIDs.contains(proposal.candidate.recordID)
            case .organizationTask: exists = organizationIDs.contains(proposal.candidate.recordID)
            case .calendarTask: exists = calendarIDs.contains(proposal.candidate.recordID)
            }
            guard exists else { throw PlannerAcceptanceError.missingSource }
        }
        for proposal in placements {
            if let value = existing.first(where: {
                $0.source == proposal.candidate.source && $0.sourceRecordID == proposal.candidate.recordID
            }) {
                value.startDate = proposal.start; value.endDate = proposal.end; value.planDate = calendar.startOfDay(for: date); value.updatedAt = now
            } else {
                context.insert(PlannedTaskPlacement(source: proposal.candidate.source, sourceRecordID: proposal.candidate.recordID,
                                                    planDate: calendar.startOfDay(for: date), startDate: proposal.start,
                                                    endDate: proposal.end, createdAt: now, updatedAt: now))
            }
        }
        try context.save()
    }
}
