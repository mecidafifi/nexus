import Foundation

enum DailyPlanNewItemStep: Equatable {
    case createCourse
    case createSchedule
}

struct DailyPlanNewItemPolicy {
    static func nextStep(courseCount: Int) -> DailyPlanNewItemStep {
        courseCount > 0 ? .createSchedule : .createCourse
    }
}
import SwiftData

/// A local weekly schedule rule. The underlying Course stays independent;
/// Daily Plan resolves this rule into transient occurrences for each date.
@Model
final class StudyScheduleRule {
    @Attribute(.unique) var id: UUID
    var courseID: UUID
    /// Gregorian Calendar weekday, Sunday = 1 ... Saturday = 7.
    var weekday: Int
    /// Local wall-clock minutes from midnight.
    var startMinutes: Int
    var durationMinutes: Int
    var effectiveStart: Date
    var effectiveEnd: Date?
    var locationOverride: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        courseID: UUID,
        weekday: Int,
        startMinutes: Int,
        durationMinutes: Int = 50,
        effectiveStart: Date = .now,
        effectiveEnd: Date? = nil,
        locationOverride: String = "",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.courseID = courseID
        self.weekday = min(max(weekday, 1), 7)
        self.startMinutes = min(max(startMinutes, 0), 1_439)
        self.durationMinutes = min(max(durationMinutes, 10), 720)
        self.effectiveStart = effectiveStart
        self.effectiveEnd = effectiveEnd
        self.locationOverride = locationOverride
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Encodes a presentation-only source warning inside the existing schedule
/// rule metadata field. This keeps the SwiftData schema unchanged while making
/// it impossible to mistake a previous-year timetable for an official one.
struct ProvisionalScheduleMetadata: Codable, Equatable {
    static let storagePrefix = "nexus-provisional-v1:"

    let modality: String?
    let sourceCourseName: String?
    let sourceCourseCode: String?

    var encodedValue: String {
        guard let data = try? JSONEncoder().encode(self) else { return Self.storagePrefix }
        return Self.storagePrefix + data.base64EncodedString()
    }

    static func decode(_ value: String) -> Self? {
        guard value.hasPrefix(storagePrefix),
              let data = Data(base64Encoded: String(value.dropFirst(storagePrefix.count))) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    func displaySummary(linkedCourse: Course?) -> String {
        var parts = [String(localized: "schedule.provisional.label")]
        if let modality, !modality.isEmpty { parts.append("[\(modality)]") }
        if let sourceCourseName, let sourceCourseCode, let linkedCourse {
            parts.append(String(
                format: String(localized: "schedule.provisional.mismatchFormat"),
                sourceCourseName, sourceCourseCode, linkedCourse.name, linkedCourse.code
            ))
        }
        return parts.joined(separator: " · ")
    }
}

enum ScheduleRulePresentationPolicy {
    static func metadata(for rule: StudyScheduleRule) -> ProvisionalScheduleMetadata? {
        ProvisionalScheduleMetadata.decode(rule.locationOverride)
    }

    static func subtitle(for rule: StudyScheduleRule, course: Course?) -> String {
        if let metadata = metadata(for: rule) { return metadata.displaySummary(linkedCourse: course) }
        let override = rule.locationOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return override.isEmpty ? (course?.location ?? "") : override
    }

    static func isProvisionalDisplayText(_ value: String) -> Bool {
        value.localizedCaseInsensitiveContains(String(localized: "schedule.provisional.label"))
    }
}

/// Provisional previous-year rules deliberately have no authoritative semester
/// boundary. Their stored import date is provenance, not a lower display bound,
/// so calendar inspection projects them on every matching selected date. Normal
/// semester rules continue to respect their explicit effective range.
enum ScheduleRuleProjectionPolicy {
    static func includes(_ rule: StudyScheduleRule, on date: Date, calendar: Calendar) -> Bool {
        let day = calendar.startOfDay(for: date)
        if ScheduleRulePresentationPolicy.metadata(for: rule) != nil { return true }
        guard day >= calendar.startOfDay(for: rule.effectiveStart) else { return false }
        if let effectiveEnd = rule.effectiveEnd, day > calendar.startOfDay(for: effectiveEnd) { return false }
        return true
    }
}

enum DailyPlanMode: String, CaseIterable, Identifiable {
    case today, week, month
    var id: String { rawValue }
    var titleKey: String { "dailyPlan.mode.\(rawValue)" }
}

enum DailyPlanSource: String, CaseIterable, Codable {
    case study, attendance, gym, finance, notes, calendar, obs, organization

    var route: AppRoute {
        switch self {
        case .study: .study
        case .attendance: .attendance
        case .gym: .gym
        case .finance: .finance
        case .notes: .notes
        case .calendar: .calendar
        case .obs: .obs
        case .organization: .organization
        }
    }
}

enum DailyPlanItemKind: String, Codable {
    case lesson, freeTime, studyTask, organizationTask, studySession, focusSession, gym, calendar, assessment, financeDue, pinnedNote
}

enum TaskPlacementSource: String, CaseIterable, Codable, Identifiable {
    case studyTask, organizationTask, calendarTask
    var id: String { rawValue }
}

/// An accepted scheduling decision. Proposals remain transient; only rows that
/// the user explicitly selects and accepts are stored. The source record keeps
/// ownership in its original feature and its due date is never rewritten.
@Model
final class PlannedTaskPlacement {
    @Attribute(.unique) var id: UUID
    var sourceRaw: String
    var sourceRecordID: UUID
    var planDate: Date
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var updatedAt: Date

    var source: TaskPlacementSource {
        get { TaskPlacementSource(rawValue: sourceRaw) ?? .studyTask }
        set { sourceRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), source: TaskPlacementSource, sourceRecordID: UUID, planDate: Date,
         startDate: Date, endDate: Date, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.sourceRaw = source.rawValue; self.sourceRecordID = sourceRecordID
        self.planDate = planDate; self.startDate = startDate; self.endDate = endDate
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

struct LessonOccurrence: Identifiable, Equatable {
    let id: String
    let ruleID: UUID
    let courseID: UUID
    let title: String
    let subtitle: String
    let start: Date
    let end: Date
}

struct DailyPlanItem: Identifiable, Equatable {
    let id: String
    let source: DailyPlanSource
    let kind: DailyPlanItemKind
    let recordID: UUID?
    let title: String
    let subtitle: String
    let start: Date?
    let end: Date?
    let isCompleted: Bool
    let isActionable: Bool
    let isImportant: Bool
    let occurrenceID: String?
    let courseID: UUID?
}

/// Presentation-only naming for Gym items in Daily Plan. The Gym entities and
/// their stored values remain untouched; the read model removes only NEXUS's
/// own generic weekly-plan prefix and weekday segment when a specific routine
/// title follows them.
enum GymSessionDisplayPolicy {
    private static let generatedPlanPrefix = "Haftalık Antrenman Planı"
    private static let weekdayNames: Set<String> = [
        "Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"
    ]

    static func title(for session: PlannedWorkoutSession, plans: [WorkoutPlan]) -> String {
        if let planID = session.planID,
           let plan = plans.first(where: { $0.id == planID }) {
            let storedName = plan.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !storedName.isEmpty { return routineTitle(from: storedName) }
        }

        let note = session.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty, !note.hasPrefix("Haftalık niyet:") { return note }
        return String(localized: "dailyPlan.workout")
    }

    static func routineTitle(from storedPlanName: String) -> String {
        let components = storedPlanName
            .components(separatedBy: " · ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard components.first?.localizedCaseInsensitiveContains(generatedPlanPrefix) == true else {
            return storedPlanName
        }

        var specific = Array(components.dropFirst())
        if let first = specific.first, weekdayNames.contains(first) { specific.removeFirst() }
        return specific.isEmpty ? storedPlanName : specific.joined(separator: " · ")
    }
}

struct DailyPlanSnapshot {
    let date: Date
    let items: [DailyPlanItem]
    let lessons: [LessonOccurrence]
    let freeBlocks: [DailyPlanItem]
    let completedCount: Int
    let actionableCount: Int
    let organizationAvailable: Bool

    var progress: Double {
        guard actionableCount > 0 else { return 0 }
        return Double(completedCount) / Double(actionableCount)
    }
}

struct DailyPlanTaskProgress: Equatable {
    let completed: Int
    let total: Int

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var countText: String { "\(completed)/\(total)" }

    var percentageText: String {
        let percentage = fraction * 100
        let rounded = percentage.rounded()
        if abs(percentage - rounded) < 0.05 { return "\(Int(rounded))%" }
        return String(format: "%.1f%%", percentage)
    }

    func asciiBar(width: Int = 20) -> String {
        let safeWidth = max(width, 1)
        let filled = min(max(Int((fraction * Double(safeWidth)).rounded(.down)), 0), safeWidth)
        return "[\(String(repeating: "█", count: filled))\(String(repeating: "·", count: safeWidth - filled))]"
    }
}

/// The TODAY task checklist intentionally includes only records whose owning
/// feature exposes a safe persisted completion flag. Lessons, assessments,
/// finance due items, notes and completed history stay outside this ratio.
enum DailyPlanTaskProgressPolicy {
    static func isCompletable(_ item: DailyPlanItem) -> Bool {
        guard item.isActionable, item.recordID != nil else { return false }
        switch item.kind {
        case .studyTask, .organizationTask, .calendar, .gym: return true
        default: return false
        }
    }

    static func tasks(from items: [DailyPlanItem]) -> [DailyPlanItem] {
        items.filter(isCompletable).sorted {
            if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
            switch ($0.start, $1.start) {
            case let (left?, right?): return left == right ? $0.id < $1.id : left < right
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return $0.id < $1.id
            }
        }
    }

    static func progress(from items: [DailyPlanItem]) -> DailyPlanTaskProgress {
        let rows = tasks(from: items)
        return DailyPlanTaskProgress(completed: rows.filter(\.isCompleted).count, total: rows.count)
    }
}

enum DailyPlanDashboardWidthClass: Equatable {
    case compact
    case medium
    case wide
}

struct DailyPlanDashboardLayoutPolicy {
    static func widthClass(for width: Double) -> DailyPlanDashboardWidthClass {
        if width >= 1_120 { return .wide }
        if width >= 780 { return .medium }
        return .compact
    }
}

struct DailyPlanTimelineBounds: Equatable {
    let startMinutes: Int
    let endMinutes: Int

    var durationMinutes: Int { max(endMinutes - startMinutes, 60) }
}

struct DailyPlanTimelineLane: Equatable {
    let itemID: String
    let lane: Int
}

/// Pure presentation policy for the DAILY PLAN time grid. It consumes only the
/// transient read-model and never changes an owning feature record.
struct DailyPlanTimelinePolicy {
    static let defaultStartMinutes = 0
    static let defaultEndMinutes = 24 * 60

    static func bounds(
        for items: [DailyPlanItem],
        on date: Date,
        calendar: Calendar = .current
    ) -> DailyPlanTimelineBounds {
        DailyPlanTimelineBounds(startMinutes: defaultStartMinutes, endMinutes: defaultEndMinutes)
    }

    static func timedItems(from snapshot: DailyPlanSnapshot) -> [DailyPlanItem] {
        (snapshot.items + snapshot.freeBlocks)
            .filter { item in
                guard item.start != nil else { return false }
                guard let end = item.end else { return true }
                return end > item.start!
            }
            .sorted {
                if $0.start == $1.start { return $0.id < $1.id }
                return $0.start! < $1.start!
            }
    }

    static func selectedDayTasks(from snapshot: DailyPlanSnapshot) -> [DailyPlanItem] {
        DailyPlanTaskProgressPolicy.tasks(from: snapshot.items)
    }

    static func hasScheduledContent(_ items: [DailyPlanItem]) -> Bool {
        items.contains { $0.kind != .freeTime }
    }

    static func isPointInTime(_ item: DailyPlanItem) -> Bool {
        guard let start = item.start else { return false }
        guard let end = item.end else { return true }
        return end <= start
    }

    /// Greedy interval coloring prevents overlapping real items from obscuring
    /// one another. Stable time/id sorting makes the result deterministic.
    static func lanes(for items: [DailyPlanItem]) -> [DailyPlanTimelineLane] {
        let scheduled = items.filter {
            $0.kind != .freeTime && $0.start != nil && ($0.end == nil || $0.end! > $0.start!)
        }.sorted {
            if $0.start == $1.start { return $0.id < $1.id }
            return $0.start! < $1.start!
        }
        var laneEnds: [Date] = []
        var output: [DailyPlanTimelineLane] = []
        for item in scheduled {
            guard let start = item.start else { continue }
            let end = item.end.flatMap { $0 > start ? $0 : nil } ?? start.addingTimeInterval(1)
            if let available = laneEnds.firstIndex(where: { $0 <= start }) {
                laneEnds[available] = end
                output.append(.init(itemID: item.id, lane: available))
            } else {
                output.append(.init(itemID: item.id, lane: laneEnds.count))
                laneEnds.append(end)
            }
        }
        return output
    }
}

/// Pinned notes are useful undated context, not seven separate dated events.
/// Keep them in the transient Daily Plan snapshot for keyboard/source access,
/// while omitting repeated copies from compact Week/Month date cards.
enum DailyPlanDatedPresentationPolicy {
    static func items(_ items: [DailyPlanItem]) -> [DailyPlanItem] {
        items.filter { $0.kind != .pinnedNote }
    }
}

enum LessonOccurrenceKey {
    /// Uses an absolute scheduled start instant. Rule ID separates two lessons
    /// of the same course on the same day and remains stable across relaunches.
    static func make(ruleID: UUID, scheduledStart: Date) -> String {
        let seconds = Int64(scheduledStart.timeIntervalSince1970.rounded())
        return "lesson:\(ruleID.uuidString.lowercased()):\(seconds)"
    }
}
