import Foundation
import SwiftData

enum VoiceDataScope: String, CaseIterable, Identifiable, Codable, Hashable {
    case study, tasks, attendance, deadlines, finance, gym, focus, calendar, obs, organization
    var id: String { rawValue }
    var titleKey: String { "voice.scope.\(rawValue)" }
}

enum VoiceReportKind: String, CaseIterable, Equatable {
    case today, week, incompleteTasks, attendanceRisk, deadlines, finance, gymAndFocus, capabilities
}

enum VoiceCommand: Equatable {
    case report(VoiceReportKind)
    case navigate(AppRoute)
    case remoteQuestion(String)
}

struct VoiceReport: Equatable {
    let kind: VoiceReportKind
    let title: String
    let spokenText: String
    let details: [String]
    let scopes: Set<VoiceDataScope>

    var transmissionPreview: String {
        ([title] + details).joined(separator: "\n")
    }
}

/// Compatibility summary used by Phase 15's full VoiceActionDraft workflow.
/// It remains inert and cannot execute a persistence write by itself.
struct VoiceProposedMutation: Identifiable, Equatable {
    enum Kind: String, Equatable { case add, edit }
    let id: UUID
    let kind: Kind
    let owner: AppRoute
    let summary: String
    let proposedFields: [String: String]
    let requiresExplicitConfirmation: Bool

    init(id: UUID = UUID(), kind: Kind, owner: AppRoute, summary: String,
         proposedFields: [String: String], requiresExplicitConfirmation: Bool = true) {
        self.id = id; self.kind = kind; self.owner = owner; self.summary = summary
        self.proposedFields = proposedFields
        self.requiresExplicitConfirmation = requiresExplicitConfirmation
    }
}

enum VoiceCommandParser {
    static func parse(_ input: String) -> VoiceCommand {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = normalized(trimmed)
        guard !text.isEmpty else { return .remoteQuestion("") }

        if text.contains("ac") || text.contains("git") || text.contains("goster") || text.contains("افتح") || text.contains("اذهب") {
            if text.contains("calisma") || text.contains("ders") || text.contains("دراسة") || text.contains("درس") { return .navigate(.study) }
            if text.contains("devam") || text.contains("katilim") { return .navigate(.attendance) }
            if text.contains("spor") || text.contains("gym") || text.contains("رياضة") || text.contains("نادي") { return .navigate(.gym) }
            if text.contains("finans") || text.contains("para") || text.contains("مالية") || text.contains("مصروف") { return .navigate(.finance) }
            if text.contains("not") || text.contains("ملاحظ") { return .navigate(.notes) }
            if text.contains("takvim") || text.contains("تقويم") { return .navigate(.calendar) }
            if text.contains("obs") || text.contains("notlarim") { return .navigate(.obs) }
            if text.contains("organizasyon") || text.contains("proje") || text.contains("مشروع") || text.contains("تنظيم") { return .navigate(.organization) }
        }
        if text.contains("neler yapabil") || text == "yardim" || text == "komutlar" { return .report(.capabilities) }
        if text.contains("devamsizlik") || text.contains("katilim riski") { return .report(.attendanceRisk) }
        if text.contains("tamamlanmamis") || text.contains("acik gorev") || text.contains("eksik gorev") { return .report(.incompleteTasks) }
        if text.contains("son tarih") || text.contains("deadline") || text.contains("yaklasan sinav") { return .report(.deadlines) }
        if text.contains("finans") || text.contains("bakiye") || text.contains("butce") || text.contains("borc") { return .report(.finance) }
        if text.contains("odak") || text.contains("spor ilerleme") || text.contains("gym ilerleme") { return .report(.gymAndFocus) }
        if text.contains("bu hafta") || text.contains("haftalik ozet") { return .report(.week) }
        if text.contains("bugun") || text.contains("gunluk ozet") { return .report(.today) }
        return .remoteQuestion(trimmed)
    }

    static func normalized(_ value: String) -> String {
        value.lowercased(with: Locale(identifier: "tr_TR"))
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "tr_TR"))
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "[^\\p{L}\\p{N} ]", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

@MainActor
enum VoiceLocalReportService {
    static func make(_ kind: VoiceReportKind, date: Date = .now, context: ModelContext, calendar: Calendar = .current) throws -> VoiceReport {
        switch kind {
        case .today: try today(date: date, context: context, calendar: calendar)
        case .week: try week(date: date, context: context, calendar: calendar)
        case .incompleteTasks: try incompleteTasks(date: date, context: context, calendar: calendar)
        case .attendanceRisk: try attendanceRisk(context: context)
        case .deadlines: try deadlines(date: date, context: context, calendar: calendar)
        case .finance: try finance(date: date, context: context, calendar: calendar)
        case .gymAndFocus: try gymAndFocus(date: date, context: context, calendar: calendar)
        case .capabilities:
            VoiceReport(kind: .capabilities, title: String(localized: "voice.report.capabilities.title"),
                        spokenText: String(localized: "voice.report.capabilities.spoken"),
                        details: [String(localized: "voice.report.capabilities.details")], scopes: [])
        }
    }

    private static func today(date: Date, context: ModelContext, calendar: Calendar) throws -> VoiceReport {
        let courses = try context.fetch(FetchDescriptor<Course>())
        let rules = try context.fetch(FetchDescriptor<StudyScheduleRule>())
        let attendance = try context.fetch(FetchDescriptor<AttendanceRecord>())
        let tasks = try context.fetch(FetchDescriptor<StudyTask>())
        let organization = try context.fetch(FetchDescriptor<OrganizationTask>())
        let entries = try context.fetch(FetchDescriptor<CalendarEntry>())
        let workouts = try context.fetch(FetchDescriptor<PlannedWorkoutSession>())
        let occurrences = DailyPlanAggregator.occurrences(rules: rules, on: date, courses: courses, calendar: calendar)
        let cancelled = Set(attendance.filter { $0.status == .cancelled }.map(\.occurrenceID))
        let heldLessons = occurrences.filter { !cancelled.contains($0.id) }.count
        let taskCount = tasks.filter { $0.status != .completed && $0.status != .cancelled && $0.dueDate.map { calendar.isDate($0, inSameDayAs: date) } == true }.count
            + organization.filter { $0.status != .completed && $0.status != .cancelled && $0.dueDate.map { calendar.isDate($0, inSameDayAs: date) } == true }.count
            + entries.filter { $0.kind == .task && !$0.isCompleted && calendar.isDate($0.startDate, inSameDayAs: date) }.count
        let events = entries.filter { $0.kind == .event && calendar.isDate($0.startDate, inSameDayAs: date) }.count
        let gym = workouts.filter { !$0.isCompleted && calendar.isDate($0.date, inSameDayAs: date) }.count
        let line = String(format: String(localized: "voice.report.today.format"), heldLessons, taskCount, events, gym)
        return VoiceReport(kind: .today, title: String(localized: "voice.report.today.title"), spokenText: line,
                           details: [line], scopes: [.study, .tasks, .attendance, .calendar, .organization, .gym])
    }

    private static func week(date: Date, context: ModelContext, calendar: Calendar) throws -> VoiceReport {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return VoiceReport(kind: .week, title: String(localized: "voice.report.week.title"), spokenText: String(localized: "voice.report.empty"), details: [], scopes: [])
        }
        let tasks = try context.fetch(FetchDescriptor<StudyTask>())
        let organization = try context.fetch(FetchDescriptor<OrganizationTask>())
        let entries = try context.fetch(FetchDescriptor<CalendarEntry>())
        let workouts = try context.fetch(FetchDescriptor<PlannedWorkoutSession>())
        let focus = try context.fetch(FetchDescriptor<FocusSessionRecord>())
        let due = tasks.filter { $0.status != .completed && $0.status != .cancelled && $0.dueDate.map(interval.contains) == true }.count
            + organization.filter { $0.status != .completed && $0.status != .cancelled && $0.dueDate.map(interval.contains) == true }.count
            + entries.filter { $0.kind == .task && !$0.isCompleted && interval.contains($0.startDate) }.count
        let events = entries.filter { $0.kind == .event && interval.contains($0.startDate) }.count
        let gymDone = workouts.filter { $0.isCompleted && interval.contains($0.date) }.count
        let focusMinutes = focus.filter { interval.contains($0.startedAt) }.reduce(0) { $0 + max($1.elapsedSeconds, 0) } / 60
        let line = String(format: String(localized: "voice.report.week.format"), due, events, gymDone, focusMinutes)
        return VoiceReport(kind: .week, title: String(localized: "voice.report.week.title"), spokenText: line,
                           details: [line], scopes: [.tasks, .calendar, .organization, .gym, .focus])
    }

    private static func incompleteTasks(date: Date, context: ModelContext, calendar: Calendar) throws -> VoiceReport {
        let study = try context.fetch(FetchDescriptor<StudyTask>()).filter { $0.status != .completed && $0.status != .cancelled }
        let organization = try context.fetch(FetchDescriptor<OrganizationTask>()).filter { $0.status != .completed && $0.status != .cancelled }
        let calendarTasks = try context.fetch(FetchDescriptor<CalendarEntry>()).filter { $0.kind == .task && !$0.isCompleted }
        let rows = (study.map { ($0.title, $0.dueDate) } + organization.map { ($0.title, $0.dueDate) } + calendarTasks.map { ($0.title, Optional($0.startDate)) })
            .sorted { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }
        let details = rows.prefix(8).map { title, due in
            due.map { "\(title) — \($0.formatted(date: .abbreviated, time: .shortened))" } ?? title
        }
        let spoken = String(format: String(localized: "voice.report.tasks.format"), rows.count)
        return VoiceReport(kind: .incompleteTasks, title: String(localized: "voice.report.tasks.title"), spokenText: spoken,
                           details: details.isEmpty ? [String(localized: "voice.report.empty")] : details,
                           scopes: [.tasks, .organization, .calendar])
    }

    private static func attendanceRisk(context: ModelContext) throws -> VoiceReport {
        let courses = try context.fetch(FetchDescriptor<Course>())
        let records = try context.fetch(FetchDescriptor<AttendanceRecord>())
        var risky: [String] = []
        for course in courses {
            let scoped = records.filter { $0.courseID == course.id }
            let summary = AttendanceSummary(present: scoped.filter { $0.status == .present }.count,
                                            absent: scoped.filter { $0.status == .absent }.count,
                                            late: scoped.filter { $0.status == .late }.count,
                                            excused: scoped.filter { $0.status == .excused }.count,
                                            cancelled: scoped.filter { $0.status == .cancelled }.count,
                                            online: scoped.filter { $0.status == .online }.count)
            let remaining = max(course.allowedAbsenceCount - summary.absent, 0)
            if summary.absent >= max(course.allowedAbsenceCount - 1, 0), summary.absent > 0 {
                let percentage = summary.percentage.map { String(format: "%.1f%%", $0) } ?? "—"
                risky.append(String(format: String(localized: "voice.report.attendance.row"), course.name, summary.absent, remaining, percentage))
            }
        }
        let spoken = risky.isEmpty ? String(localized: "voice.report.attendance.none") : String(format: String(localized: "voice.report.attendance.format"), risky.count)
        return VoiceReport(kind: .attendanceRisk, title: String(localized: "voice.report.attendance.title"), spokenText: spoken,
                           details: risky.isEmpty ? [spoken] : risky, scopes: [.attendance, .study])
    }

    private static func deadlines(date: Date, context: ModelContext, calendar: Calendar) throws -> VoiceReport {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 8, to: start) ?? start
        var rows: [(String, Date)] = []
        rows += try context.fetch(FetchDescriptor<StudyTask>()).compactMap { $0.status != .completed && $0.status != .cancelled && $0.dueDate.map { $0 < end } == true ? ($0.title, $0.dueDate!) : nil }
        rows += try context.fetch(FetchDescriptor<OrganizationTask>()).compactMap { $0.status != .completed && $0.status != .cancelled && $0.dueDate.map { $0 < end } == true ? ($0.title, $0.dueDate!) : nil }
        rows += try context.fetch(FetchDescriptor<CalendarEntry>()).compactMap { $0.kind != .event && !$0.isCompleted && $0.startDate < end ? ($0.title, $0.startDate) : nil }
        rows += try context.fetch(FetchDescriptor<OBSAssessment>()).compactMap { $0.earnedPoints == nil && $0.dueDate < end ? ($0.title, $0.dueDate) : nil }
        rows.sort { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 < $1.1 }
        let details = rows.prefix(8).map { "\($0.0) — \($0.1.formatted(date: .abbreviated, time: .shortened))" }
        let spoken = String(format: String(localized: "voice.report.deadlines.format"), rows.count)
        return VoiceReport(kind: .deadlines, title: String(localized: "voice.report.deadlines.title"), spokenText: spoken,
                           details: details.isEmpty ? [String(localized: "voice.report.empty")] : details,
                           scopes: [.deadlines, .tasks, .organization, .calendar, .obs])
    }

    private static func finance(date: Date, context: ModelContext, calendar: Calendar) throws -> VoiceReport {
        let entries = try context.fetch(FetchDescriptor<FinanceEntry>())
        let debts = try context.fetch(FetchDescriptor<DebtRecord>())
        let budgets = try context.fetch(FetchDescriptor<MonthlyBudget>())
        let currency = UserDefaults.standard.string(forKey: "finance.defaultCurrency") ?? "TRY"
        let summary = FinanceViewModel().summary(entries: entries, debts: debts, budgets: budgets, month: date, currencyCode: currency, calendar: calendar)
        let income = money(summary.incomeMinorUnits, currency: currency)
        let expense = money(summary.expenseMinorUnits, currency: currency)
        let balance = money(summary.balanceMinorUnits, currency: currency)
        let debt = money(summary.netDebtPositionMinorUnits, currency: currency)
        let line = String(format: String(localized: "voice.report.finance.format"), income, expense, balance, debt)
        return VoiceReport(kind: .finance, title: String(localized: "voice.report.finance.title"), spokenText: line, details: [line], scopes: [.finance])
    }

    private static func gymAndFocus(date: Date, context: ModelContext, calendar: Calendar) throws -> VoiceReport {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
        let planned = try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).filter { interval.contains($0.date) }
        let logs = try context.fetch(FetchDescriptor<WorkoutRecord>()).filter { interval.contains($0.date) }
        let focusMinutes = try context.fetch(FetchDescriptor<FocusSessionRecord>()).filter { interval.contains($0.startedAt) }.reduce(0) { $0 + max($1.elapsedSeconds, 0) } / 60
        let line = String(format: String(localized: "voice.report.gymFocus.format"), planned.filter(\.isCompleted).count, planned.count, logs.count, focusMinutes)
        return VoiceReport(kind: .gymAndFocus, title: String(localized: "voice.report.gymFocus.title"), spokenText: line, details: [line], scopes: [.gym, .focus])
    }

    private static func money(_ minor: Int, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter.string(from: NSNumber(value: Double(minor) / 100)) ?? "\(Double(minor) / 100) \(currency)"
    }
}
