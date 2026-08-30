import Foundation
import SwiftData

enum CalendarDisplayMode: String, CaseIterable, Identifiable { case month, week; var id: String { rawValue }; var titleKey: String { "calendar.view.\(rawValue)" } }

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var displayedDate = Date.now
    @Published var selectedDate = Calendar.current.startOfDay(for: .now)
    @Published var displayMode: CalendarDisplayMode = .month
    @Published var searchText = ""
    @Published var kindFilter: CalendarEntryKind?
    @Published var statusMessageKey = "status.ready"
    @Published var errorMessage: String?

    func move(_ amount: Int) {
        let component: Calendar.Component = displayMode == .month ? .month : .weekOfYear
        displayedDate = Calendar.current.date(byAdding: component, value: amount, to: displayedDate) ?? displayedDate
        selectedDate = Calendar.current.startOfDay(for: displayedDate)
    }

    func goToday() { displayedDate = .now; selectedDate = Calendar.current.startOfDay(for: .now) }

    func monthDays(for date: Date, calendar: Calendar = .current) -> [Date] {
        guard let month = calendar.dateInterval(of: .month, for: date),
              let week = calendar.dateInterval(of: .weekOfYear, for: month.start) else { return [] }
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
    }

    func weekDays(for date: Date, calendar: Calendar = .current) -> [Date] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func entries(_ entries: [CalendarEntry], on day: Date, calendar: Calendar = .current) -> [CalendarEntry] {
        filtered(entries).filter { entry in
            calendar.isDate(entry.startDate, inSameDayAs: day) || (entry.startDate < calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day))! && entry.endDate >= calendar.startOfDay(for: day))
        }.sorted { $0.startDate < $1.startDate }
    }

    func studyTasks(_ tasks: [StudyTask], on day: Date, calendar: Calendar = .current) -> [StudyTask] {
        tasks.filter { task in
            guard let due = task.dueDate, calendar.isDate(due, inSameDayAs: day) else { return false }
            return searchText.isEmpty || task.title.localizedCaseInsensitiveContains(searchText)
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func filtered(_ entries: [CalendarEntry]) -> [CalendarEntry] {
        entries.filter { entry in
            (searchText.isEmpty || entry.title.localizedCaseInsensitiveContains(searchText) || entry.details.localizedCaseInsensitiveContains(searchText)) && (kindFilter == nil || entry.kind == kindFilter)
        }
    }

    func save(_ entry: CalendarEntry?, title: String, details: String, startDate: Date, endDate: Date, isAllDay: Bool, kind: CalendarEntryKind, isCompleted: Bool, hasReminder: Bool, reminderDate: Date, relatedRecordID: UUID?, courseID: UUID?, context: ModelContext) throws {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw CalendarValidationError.emptyTitle }
        guard endDate >= startDate else { throw CalendarValidationError.invalidRange }
        if hasReminder && reminderDate > startDate { throw CalendarValidationError.reminderAfterStart }
        if let entry {
            entry.title = clean; entry.details = details; entry.startDate = startDate; entry.endDate = endDate; entry.isAllDay = isAllDay
            entry.kind = kind; entry.isCompleted = isCompleted; entry.reminderDate = hasReminder ? reminderDate : nil
            entry.relatedRecordID = relatedRecordID; entry.courseID = courseID; entry.updatedAt = .now
        } else {
            context.insert(CalendarEntry(title: clean, details: details, startDate: startDate, endDate: endDate, isAllDay: isAllDay, kind: kind, isCompleted: isCompleted, reminderDate: hasReminder ? reminderDate : nil, relatedRecordID: relatedRecordID, courseID: courseID))
        }
        try commit(context)
    }

    func delete(_ entry: CalendarEntry, context: ModelContext) throws { context.delete(entry); try commit(context) }

    private func commit(_ context: ModelContext) throws {
        do { try context.save(); errorMessage = nil; statusMessageKey = "status.saved" }
        catch { errorMessage = error.localizedDescription; statusMessageKey = "status.saveFailed"; throw error }
    }
}

enum CalendarValidationError: LocalizedError {
    case emptyTitle, invalidRange, reminderAfterStart
    var errorDescription: String? { switch self {
    case .emptyTitle: String(localized: "validation.titleRequired")
    case .invalidRange: String(localized: "validation.dateRange")
    case .reminderAfterStart: String(localized: "calendar.validation.reminder")
    } }
}
