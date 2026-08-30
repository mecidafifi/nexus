import Foundation
import SwiftData

// Stable local-first persistence boundaries shared by the feature modules.
enum AttendanceStatus: String, CaseIterable, Codable, Identifiable {
    case present, absent, cancelled, online, late, excused
    var id: String { rawValue }
    var titleKey: String { "attendance.status.\(rawValue)" }
    var symbol: String { switch self { case .present: "checkmark.circle"; case .absent: "xmark.circle"; case .cancelled: "nosign"; case .online: "video"; case .late: "clock.badge.exclamationmark"; case .excused: "minus.circle" } }
}

@Model
final class AttendanceRecord {
    @Attribute(.unique) var id: UUID
    var courseID: UUID?
    var date: Date
    var wasPresent: Bool
    var note: String
    var statusRaw: String = ""
    // Phase 5: a scheduled lesson occurrence is identified independently from
    // its recurring rule. This lets Daily Plan mark one date without touching
    // the series or any future occurrence.
    var occurrenceID: String = ""
    var scheduleRuleID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var status: AttendanceStatus {
        get { AttendanceStatus(rawValue: statusRaw) ?? (wasPresent ? .present : .absent) }
        set { statusRaw = newValue.rawValue; wasPresent = newValue == .present || newValue == .late || newValue == .online }
    }

    init(id: UUID = UUID(), courseID: UUID? = nil, date: Date = .now, status: AttendanceStatus = .present, note: String = "", occurrenceID: String = "", scheduleRuleID: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.courseID = courseID; self.date = date; self.wasPresent = status == .present || status == .late || status == .online
        self.note = note; self.statusRaw = status.rawValue; self.occurrenceID = occurrenceID; self.scheduleRuleID = scheduleRuleID
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
enum FinanceTransactionType: String, CaseIterable, Codable, Identifiable {
    case income, expense
    var id: String { rawValue }
    var titleKey: String { "finance.type.\(rawValue)" }
}

@Model
final class FinanceEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var amountMinorUnits: Int
    var currencyCode: String
    var category: String
    var typeRaw: String = ""
    var categoryID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var type: FinanceTransactionType {
        get { FinanceTransactionType(rawValue: typeRaw) ?? (amountMinorUnits < 0 ? .expense : .income) }
        set { typeRaw = newValue.rawValue }
    }
    var normalizedAmountMinorUnits: Int { abs(amountMinorUnits) }

    init(id: UUID = UUID(), date: Date = .now, title: String, amountMinorUnits: Int, currencyCode: String = "TRY", category: String = "", type: FinanceTransactionType? = nil, categoryID: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.date = date; self.title = title; self.amountMinorUnits = amountMinorUnits
        self.currencyCode = currencyCode; self.category = category; self.typeRaw = (type ?? (amountMinorUnits < 0 ? .expense : .income)).rawValue
        self.categoryID = categoryID; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class FinanceCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var typeRaw: String
    var createdAt: Date
    var type: FinanceTransactionType { get { FinanceTransactionType(rawValue: typeRaw) ?? .expense } set { typeRaw = newValue.rawValue } }
    init(id: UUID = UUID(), name: String, type: FinanceTransactionType = .expense, createdAt: Date = .now) { self.id = id; self.name = name; self.typeRaw = type.rawValue; self.createdAt = createdAt }
}

@Model
final class MonthlyBudget {
    @Attribute(.unique) var id: UUID
    var monthStart: Date
    var amountMinorUnits: Int
    var currencyCode: String
    var createdAt: Date
    var updatedAt: Date
    init(id: UUID = UUID(), monthStart: Date, amountMinorUnits: Int, currencyCode: String = "TRY", createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.monthStart = monthStart; self.amountMinorUnits = amountMinorUnits; self.currencyCode = currencyCode; self.createdAt = createdAt; self.updatedAt = updatedAt }
}

enum RecurrenceCadence: String, CaseIterable, Codable, Identifiable {
    case weekly, monthly, yearly
    var id: String { rawValue }
    var titleKey: String { "finance.recurrence.\(rawValue)" }
}

@Model
final class RecurringTransaction {
    @Attribute(.unique) var id: UUID
    var title: String
    var amountMinorUnits: Int
    var currencyCode: String
    var typeRaw: String
    var categoryID: UUID?
    var startDate: Date
    var nextDate: Date
    var cadenceRaw: String
    var isActive: Bool
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var type: FinanceTransactionType { get { FinanceTransactionType(rawValue: typeRaw) ?? .expense } set { typeRaw = newValue.rawValue } }
    var cadence: RecurrenceCadence { get { RecurrenceCadence(rawValue: cadenceRaw) ?? .monthly } set { cadenceRaw = newValue.rawValue } }
    init(id: UUID = UUID(), title: String, amountMinorUnits: Int, currencyCode: String = "TRY", type: FinanceTransactionType = .expense, categoryID: UUID? = nil, startDate: Date = .now, nextDate: Date = .now, cadence: RecurrenceCadence = .monthly, isActive: Bool = true, note: String = "", createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.title = title; self.amountMinorUnits = amountMinorUnits; self.currencyCode = currencyCode; self.typeRaw = type.rawValue; self.categoryID = categoryID; self.startDate = startDate; self.nextDate = nextDate; self.cadenceRaw = cadence.rawValue; self.isActive = isActive; self.note = note; self.createdAt = createdAt; self.updatedAt = updatedAt }
}

enum DebtDirection: String, CaseIterable, Codable, Identifiable {
    case owedByUser, owedToUser
    var id: String { rawValue }
    var titleKey: String { "finance.debt.direction.\(rawValue)" }
}
enum DebtStatus: String, CaseIterable, Codable, Identifiable {
    case outstanding, paid, cancelled
    var id: String { rawValue }
    var titleKey: String { "finance.debt.status.\(rawValue)" }
}

@Model
final class DebtRecord {
    @Attribute(.unique) var id: UUID
    var counterparty: String
    var amountMinorUnits: Int
    var currencyCode: String
    var directionRaw: String
    var dueDate: Date?
    var statusRaw: String
    var note: String
    var createdAt: Date
    var updatedAt: Date
    var direction: DebtDirection { get { DebtDirection(rawValue: directionRaw) ?? .owedByUser } set { directionRaw = newValue.rawValue } }
    var status: DebtStatus { get { DebtStatus(rawValue: statusRaw) ?? .outstanding } set { statusRaw = newValue.rawValue } }
    init(id: UUID = UUID(), counterparty: String, amountMinorUnits: Int, currencyCode: String = "TRY", direction: DebtDirection = .owedByUser, dueDate: Date? = nil, status: DebtStatus = .outstanding, note: String = "", createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.counterparty = counterparty; self.amountMinorUnits = amountMinorUnits; self.currencyCode = currencyCode; self.directionRaw = direction.rawValue; self.dueDate = dueDate; self.statusRaw = status.rawValue; self.note = note; self.createdAt = createdAt; self.updatedAt = updatedAt }
}

@Model
final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var durationMinutes: Int
    var note: String
    var planID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    init(id: UUID = UUID(), date: Date = .now, title: String, durationMinutes: Int = 45, note: String = "", planID: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.date = date; self.title = title; self.durationMinutes = durationMinutes; self.note = note; self.planID = planID; self.createdAt = createdAt; self.updatedAt = updatedAt }
}

@Model final class WorkoutPlan { @Attribute(.unique) var id: UUID; var name: String; var goal: String; var isActive: Bool; var nextSessionDate: Date?; var createdAt: Date; var updatedAt: Date; init(id: UUID = UUID(), name: String, goal: String = "", isActive: Bool = true, nextSessionDate: Date? = nil, createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.name = name; self.goal = goal; self.isActive = isActive; self.nextSessionDate = nextSessionDate; self.createdAt = createdAt; self.updatedAt = updatedAt } }
@Model final class ExerciseDefinition { @Attribute(.unique) var id: UUID; var name: String; var muscleGroup: String; var defaultSets: Int; var defaultReps: Int; var defaultWeight: Double; var createdAt: Date; var updatedAt: Date; init(id: UUID = UUID(), name: String, muscleGroup: String = "", defaultSets: Int = 3, defaultReps: Int = 10, defaultWeight: Double = 0, createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.name = name; self.muscleGroup = muscleGroup; self.defaultSets = defaultSets; self.defaultReps = defaultReps; self.defaultWeight = defaultWeight; self.createdAt = createdAt; self.updatedAt = updatedAt } }
@Model final class PlannedWorkoutExercise { @Attribute(.unique) var id: UUID; var planID: UUID; var exerciseID: UUID; var order: Int; var targetSets: Int; var targetReps: Int; var targetWeight: Double; init(id: UUID = UUID(), planID: UUID, exerciseID: UUID, order: Int = 0, targetSets: Int = 3, targetReps: Int = 10, targetWeight: Double = 0) { self.id = id; self.planID = planID; self.exerciseID = exerciseID; self.order = order; self.targetSets = targetSets; self.targetReps = targetReps; self.targetWeight = targetWeight } }
@Model final class PlannedWorkoutSession { @Attribute(.unique) var id: UUID; var planID: UUID?; var date: Date; var isCompleted: Bool; var note: String; var createdAt: Date; var updatedAt: Date; init(id: UUID = UUID(), planID: UUID? = nil, date: Date = .now, isCompleted: Bool = false, note: String = "", createdAt: Date = .now, updatedAt: Date = .now) { self.id = id; self.planID = planID; self.date = date; self.isCompleted = isCompleted; self.note = note; self.createdAt = createdAt; self.updatedAt = updatedAt } }
@Model final class CompletedExerciseLog { @Attribute(.unique) var id: UUID; var sessionID: UUID; var exerciseID: UUID; var sets: Int; var reps: Int; var weight: Double; var note: String; init(id: UUID = UUID(), sessionID: UUID, exerciseID: UUID, sets: Int, reps: Int, weight: Double = 0, note: String = "") { self.id = id; self.sessionID = sessionID; self.exerciseID = exerciseID; self.sets = sets; self.reps = reps; self.weight = weight; self.note = note } }

@Model
final class NexusNote {
    @Attribute(.unique) var id: UUID
    var title: String
    var body: String
    var folderID: UUID?
    var isPinned: Bool = false
    var createdAt: Date = Date.now
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, body: String = "", folderID: UUID? = nil, isPinned: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.body = body; self.folderID = folderID; self.isPinned = isPinned
        self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class NoteFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    init(id: UUID = UUID(), name: String, createdAt: Date = .now) { self.id = id; self.name = name; self.createdAt = createdAt }
}

@Model
final class NoteTag {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    init(id: UUID = UUID(), name: String, createdAt: Date = .now) { self.id = id; self.name = name; self.createdAt = createdAt }
}

@Model
final class NoteTagAssignment {
    @Attribute(.unique) var id: UUID
    var noteID: UUID
    var tagID: UUID
    init(id: UUID = UUID(), noteID: UUID, tagID: UUID) { self.id = id; self.noteID = noteID; self.tagID = tagID }
}

enum CalendarEntryKind: String, CaseIterable, Codable, Identifiable {
    case event, task, reminder
    var id: String { rawValue }
    var titleKey: String { "calendar.kind.\(rawValue)" }
    var symbol: String { switch self { case .event: "calendar"; case .task: "checklist"; case .reminder: "bell" } }
}

@Model
final class CalendarEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String = ""
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool = false
    var kindRaw: String = "event"
    var isCompleted: Bool = false
    var reminderDate: Date?
    var relatedRecordID: UUID?
    var courseID: UUID?
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var kind: CalendarEntryKind {
        get { CalendarEntryKind(rawValue: kindRaw) ?? .event }
        set { kindRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), title: String, details: String = "", startDate: Date, endDate: Date, isAllDay: Bool = false, kind: CalendarEntryKind = .event, isCompleted: Bool = false, reminderDate: Date? = nil, relatedRecordID: UUID? = nil, courseID: UUID? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.details = details; self.startDate = startDate; self.endDate = endDate
        self.isAllDay = isAllDay; self.kindRaw = kind.rawValue; self.isCompleted = isCompleted; self.reminderDate = reminderDate
        self.relatedRecordID = relatedRecordID; self.courseID = courseID; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model final class GradeRecord { @Attribute(.unique) var id: UUID; var courseID: UUID?; var title: String; var score: Double; var maximumScore: Double; var weight: Double; init(id: UUID = UUID(), courseID: UUID? = nil, title: String, score: Double, maximumScore: Double = 100, weight: Double = 1) { self.id = id; self.courseID = courseID; self.title = title; self.score = score; self.maximumScore = maximumScore; self.weight = weight } }
enum OrganizationPriority: String, CaseIterable, Codable, Identifiable {
    case low, normal, high, critical
    var id: String { rawValue }
    var titleKey: String { "organization.priority.\(rawValue)" }
}

enum OrganizationStatus: String, CaseIterable, Codable, Identifiable {
    case planned, active, blocked, completed, cancelled
    var id: String { rawValue }
    var titleKey: String { "organization.status.\(rawValue)" }
}

@Model
final class ProjectRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var dueDate: Date?
    var isArchived: Bool
    var priorityRaw: String = "normal"
    var statusRaw: String = "planned"
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var priority: OrganizationPriority { get { OrganizationPriority(rawValue: priorityRaw) ?? .normal } set { priorityRaw = newValue.rawValue } }
    var status: OrganizationStatus { get { OrganizationStatus(rawValue: statusRaw) ?? .planned } set { statusRaw = newValue.rawValue } }
    init(id: UUID = UUID(), title: String, details: String = "", dueDate: Date? = nil, isArchived: Bool = false, priority: OrganizationPriority = .normal, status: OrganizationStatus = .planned, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.details = details; self.dueDate = dueDate; self.isArchived = isArchived
        self.priorityRaw = priority.rawValue; self.statusRaw = status.rawValue; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

@Model
final class OrganizationTask {
    @Attribute(.unique) var id: UUID
    var projectID: UUID
    var parentTaskID: UUID?
    var title: String
    var details: String
    var dueDate: Date?
    var priorityRaw: String
    var statusRaw: String
    var order: Int
    var overdueReviewedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var priority: OrganizationPriority { get { OrganizationPriority(rawValue: priorityRaw) ?? .normal } set { priorityRaw = newValue.rawValue } }
    var status: OrganizationStatus { get { OrganizationStatus(rawValue: statusRaw) ?? .planned } set { statusRaw = newValue.rawValue } }
    init(id: UUID = UUID(), projectID: UUID, parentTaskID: UUID? = nil, title: String, details: String = "", dueDate: Date? = nil, priority: OrganizationPriority = .normal, status: OrganizationStatus = .planned, order: Int = 0, overdueReviewedAt: Date? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.projectID = projectID; self.parentTaskID = parentTaskID; self.title = title; self.details = details
        self.dueDate = dueDate; self.priorityRaw = priority.rawValue; self.statusRaw = status.rawValue; self.order = order
        self.overdueReviewedAt = overdueReviewedAt; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}
