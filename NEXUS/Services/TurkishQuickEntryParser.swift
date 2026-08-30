import Foundation
import SwiftData

enum QuickEntryDraftKind: String, Codable, CaseIterable, Identifiable {
    case weeklyLesson, weeklyGym, studyTask, calendarTask, calendarEvent, gymSession
    var id: String { rawValue }
    var titleKey: String { "quickEntry.kind.\(rawValue)" }
}

struct QuickEntryDraft: Equatable {
    var kind: QuickEntryDraftKind
    var title: String
    var startMinutes: Int
    var durationMinutes: Int
    var weekday: Int?
    var effectiveStart: Date
    var effectiveEnd: Date?
    var occurrenceDates: [Date]
    let originalText: String
}

enum QuickEntryParseError: Error, LocalizedError, Equatable {
    case empty, unsupported, ambiguous, invalidTime, invalidDate, impossibleCount
    var errorDescription: String? {
        switch self {
        case .empty: String(localized: "quickEntry.error.empty")
        case .unsupported: String(localized: "quickEntry.error.unsupported")
        case .ambiguous: String(localized: "quickEntry.error.ambiguous")
        case .invalidTime: String(localized: "quickEntry.error.time")
        case .invalidDate: String(localized: "quickEntry.error.date")
        case .impossibleCount: String(localized: "quickEntry.error.count")
        }
    }
}

/// Deterministic Turkish grammar. Parsing never writes data; the explicit final
/// noun selects the independent destination model.
enum TurkishQuickEntryParser {
    private static let locale = Locale(identifier: "tr_TR")
    private static let weekdays = ["pazar": 1, "pazartesi": 2, "salı": 3, "çarşamba": 4, "perşembe": 5, "cuma": 6, "cumartesi": 7]
    private static let months = ["ocak": 1, "şubat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "haziran": 6, "temmuz": 7, "ağustos": 8, "eylül": 9, "ekim": 10, "kasım": 11, "aralık": 12]
    private static let counts = ["bir": 1, "iki": 2, "üç": 3, "dört": 4, "beş": 5, "altı": 6, "yedi": 7, "sekiz": 8]
    private static let dateExpression = #"(bugün|yarın|öbür\s+gün|bu\s+hafta\s+(?:pazartesi|salı|çarşamba|perşembe|cuma|cumartesi|pazar)|(?:pazartesi|salı|çarşamba|perşembe|cuma|cumartesi|pazar)|\d{1,2}\s+(?:ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)(?:\s+\d{4})?)"#

    static func parse(_ input: String, referenceDate: Date = .now, calendar: Calendar = .current) throws -> QuickEntryDraft {
        let source = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "’", with: "'").replacingOccurrences(of: "‘", with: "'")
        guard !source.isEmpty else { throw QuickEntryParseError.empty }
        if let result = try recurringLesson(source, referenceDate, calendar) { return result }
        if let result = try weeklyGym(source, referenceDate, calendar) { return result }
        if let result = try datedEntry(source, referenceDate, calendar) { return result }
        if source.localizedCaseInsensitiveContains(" ya da ") || source.localizedCaseInsensitiveContains(" veya ") { throw QuickEntryParseError.ambiguous }
        if let groups = captures(#"saat\s+(\d{1,3})"#, in: source), let hour = Int(groups[0]), hour > 23 { throw QuickEntryParseError.invalidTime }
        throw QuickEntryParseError.unsupported
    }

    private static func recurringLesson(_ source: String, _ referenceDate: Date, _ calendar: Calendar) throws -> QuickEntryDraft? {
        let prefix = #"^(?:her\s+)?(pazartesi|salı|çarşamba|perşembe|cuma|cumartesi|pazar)(?:\s+günleri)?\s+saat\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s*'?d[ae]\s+(.+?)\s+(?:dersi\s+)?var\s*,?\s*"#
        let until = prefix + #"(\d{1,2})\s+(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)(?:\s+(\d{4}))?\s*'?[ae]\s+kadar$"#
        if let g = captures(until, in: source) {
            let time = try validTime(g[1], g[2])
            guard let weekday = weekdays[g[0].lowercased(with: locale)] else { throw QuickEntryParseError.invalidDate }
            let end = try explicitDate(g[4], g[5], g[6], referenceDate, calendar)
            guard end >= calendar.startOfDay(for: referenceDate) else { throw QuickEntryParseError.invalidDate }
            return lesson(g[3], weekday, time, calendar.startOfDay(for: referenceDate), end, 50, source)
        }
        let countPattern = prefix + #"(bir|iki|üç|dört|beş|altı|yedi|sekiz|\d+)\s+kez$"#
        if let g = captures(countPattern, in: source) {
            let time = try validTime(g[1], g[2])
            guard let weekday = weekdays[g[0].lowercased(with: locale)] else { throw QuickEntryParseError.invalidDate }
            let countText = g[4].lowercased(with: locale)
            guard let count = counts[countText] ?? Int(countText), (1...104).contains(count) else { throw QuickEntryParseError.impossibleCount }
            let start = calendar.startOfDay(for: referenceDate)
            guard let first = nextWeekday(weekday, start, true, calendar), let end = calendar.date(byAdding: .day, value: 7 * (count - 1), to: first) else { throw QuickEntryParseError.invalidDate }
            return lesson(g[3], weekday, time, start, end, 50, source)
        }
        return nil
    }

    private static func weeklyGym(_ source: String, _ referenceDate: Date, _ calendar: Calendar) throws -> QuickEntryDraft? {
        guard let g = captures(#"^bu\s+hafta\s+saat\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s*'?d[ae]n\s+sonra\s+(bir|iki|üç|dört|beş|altı|yedi|\d+)\s+kez\s+spor$"#, in: source) else { return nil }
        let time = try validTime(g[0], g[1])
        let countText = g[2].lowercased(with: locale)
        guard let count = counts[countText] ?? Int(countText), (1...7).contains(count), let week = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else { throw QuickEntryParseError.impossibleCount }
        let today = calendar.startOfDay(for: referenceDate)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }.filter { day in
            guard day >= today, day < week.end, let date = calendar.date(byAdding: .minute, value: time, to: day) else { return false }
            return day > today || date > referenceDate
        }
        guard count <= days.count else { throw QuickEntryParseError.impossibleCount }
        let dates = spread(count, days).compactMap { calendar.date(byAdding: .minute, value: time, to: $0) }
        return QuickEntryDraft(kind: .weeklyGym, title: String(localized: "quickEntry.gym.defaultTitle"), startMinutes: time, durationMinutes: 60, weekday: nil, effectiveStart: today, effectiveEnd: week.end.addingTimeInterval(-1), occurrenceDates: dates, originalText: source)
    }

    private static func datedEntry(_ source: String, _ referenceDate: Date, _ calendar: Calendar) throws -> QuickEntryDraft? {
        let nounPattern = #"(çalışma\s+görevi|takvim\s+görevi|görev|etkinliği|etkinlik|dersi|ders|spor)"#
        let rangePattern = "^" + dateExpression + #"\s+saat\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s*(?:-|–|ile)\s*(\d{1,2})(?:[:\.]([0-5]\d))?\s+(.+?)\s+"# + nounPattern + "$"
        if let g = captures(rangePattern, in: source) {
            let day = try resolveDate(g[0], referenceDate, calendar)
            let startMinutes = try validTime(g[1], g[2])
            let endMinutes = try validTime(g[3], g[4])
            guard endMinutes > startMinutes, (10...720).contains(endMinutes - startMinutes) else { throw QuickEntryParseError.invalidTime }
            return try datedDraft(day: day, time: startMinutes, duration: endMinutes - startMinutes, title: g[5], noun: g[6], source: source, referenceDate: referenceDate, calendar: calendar)
        }
        let turkishRangePattern = "^" + dateExpression + #"\s+saat\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s*'?[dt][ae]n\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s*'?[ae]\s+(.+?)\s+"# + nounPattern + "$"
        if let g = captures(turkishRangePattern, in: source) {
            let day = try resolveDate(g[0], referenceDate, calendar)
            let startMinutes = try validTime(g[1], g[2])
            let endMinutes = try validTime(g[3], g[4])
            guard endMinutes > startMinutes, (10...720).contains(endMinutes - startMinutes) else { throw QuickEntryParseError.invalidTime }
            return try datedDraft(day: day, time: startMinutes, duration: endMinutes - startMinutes, title: g[5], noun: g[6], source: source, referenceDate: referenceDate, calendar: calendar)
        }
        let pattern = "^" + dateExpression + #"\s+saat\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s*'?(?:d[ae]|t[ae])?\s+(.+?)\s+(çalışma\s+görevi|takvim\s+görevi|görev|etkinliği|etkinlik|dersi|ders|spor)(?:\s*,?\s*(\d+)\s*(dakika|saat))?$"#
        guard let g = captures(pattern, in: source) else { return nil }
        let day = try resolveDate(g[0], referenceDate, calendar)
        let time = try validTime(g[1], g[2])
        let noun = g[4].lowercased(with: locale)
        return try datedDraft(day: day, time: time, duration: duration(g[5], g[6], noun.contains("ders") ? 50 : 60), title: g[3], noun: noun, source: source, referenceDate: referenceDate, calendar: calendar)
    }

    private static func datedDraft(day: Date, time: Int, duration: Int, title rawTitle: String, noun rawNoun: String, source: String, referenceDate: Date, calendar: Calendar) throws -> QuickEntryDraft {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw QuickEntryParseError.unsupported }
        let noun = rawNoun.lowercased(with: locale)
        guard let start = calendar.date(byAdding: .minute, value: time, to: day), start >= calendar.startOfDay(for: referenceDate) else { throw QuickEntryParseError.invalidDate }
        if noun.contains("ders") { return lesson(title, calendar.component(.weekday, from: day), time, day, day, duration, source) }
        let kind: QuickEntryDraftKind = noun.contains("etkin") ? .calendarEvent : noun.contains("spor") ? .gymSession : noun.contains("çalışma") ? .studyTask : .calendarTask
        return QuickEntryDraft(kind: kind, title: title, startMinutes: time, durationMinutes: duration, weekday: nil, effectiveStart: start, effectiveEnd: calendar.date(byAdding: .minute, value: duration, to: start), occurrenceDates: [], originalText: source)
    }

    private static func lesson(_ title: String, _ weekday: Int, _ time: Int, _ start: Date, _ end: Date, _ duration: Int, _ input: String) -> QuickEntryDraft {
        QuickEntryDraft(kind: .weeklyLesson, title: title.trimmingCharacters(in: .whitespacesAndNewlines), startMinutes: time, durationMinutes: duration, weekday: weekday, effectiveStart: start, effectiveEnd: end, occurrenceDates: [], originalText: input)
    }

    private static func validTime(_ hourText: String, _ minuteText: String) throws -> Int {
        guard let hour = Int(hourText), let minute = Int(minuteText.isEmpty ? "0" : minuteText), (0...23).contains(hour), (0...59).contains(minute) else { throw QuickEntryParseError.invalidTime }
        return hour * 60 + minute
    }

    private static func duration(_ valueText: String, _ unit: String, _ fallback: Int) throws -> Int {
        guard !valueText.isEmpty else { return fallback }
        guard let value = Int(valueText), value > 0 else { throw QuickEntryParseError.invalidTime }
        let minutes = unit.lowercased(with: locale) == "saat" ? value * 60 : value
        guard (10...720).contains(minutes) else { throw QuickEntryParseError.invalidTime }
        return minutes
    }

    private static func resolveDate(_ raw: String, _ referenceDate: Date, _ calendar: Calendar) throws -> Date {
        let phrase = raw.lowercased(with: locale).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let today = calendar.startOfDay(for: referenceDate)
        if phrase == "bugün" { return today }
        if phrase == "yarın" { return calendar.date(byAdding: .day, value: 1, to: today)! }
        if phrase == "öbür gün" { return calendar.date(byAdding: .day, value: 2, to: today)! }
        if phrase.hasPrefix("bu hafta ") {
            let name = String(phrase.dropFirst("bu hafta ".count))
            guard let weekday = weekdays[name], let week = calendar.dateInterval(of: .weekOfYear, for: referenceDate),
                  let date = (0..<7).compactMap({ calendar.date(byAdding: .day, value: $0, to: week.start) }).first(where: { calendar.component(.weekday, from: $0) == weekday }), date >= today else { throw QuickEntryParseError.invalidDate }
            return date
        }
        if let weekday = weekdays[phrase], let date = nextWeekday(weekday, today, true, calendar) { return date }
        let parts = phrase.split(separator: " ").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { throw QuickEntryParseError.invalidDate }
        return try explicitDate(parts[0], parts[1], parts.count == 3 ? parts[2] : "", referenceDate, calendar)
    }

    private static func explicitDate(_ dayText: String, _ monthText: String, _ yearText: String, _ referenceDate: Date, _ calendar: Calendar) throws -> Date {
        guard let day = Int(dayText), let month = months[monthText.lowercased(with: locale)] else { throw QuickEntryParseError.invalidDate }
        var year = Int(yearText) ?? calendar.component(.year, from: referenceDate)
        func make(_ year: Int) -> Date? {
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)), calendar.component(.year, from: date) == year, calendar.component(.month, from: date) == month, calendar.component(.day, from: date) == day else { return nil }
            return calendar.startOfDay(for: date)
        }
        guard var date = make(year) else { throw QuickEntryParseError.invalidDate }
        if yearText.isEmpty && date < calendar.startOfDay(for: referenceDate) {
            year += 1
            guard let next = make(year) else { throw QuickEntryParseError.invalidDate }
            date = next
        }
        return date
    }

    private static func nextWeekday(_ weekday: Int, _ start: Date, _ includeToday: Bool, _ calendar: Calendar) -> Date? {
        let range = includeToday ? 0...14 : 1...14
        guard let offset = range.first(where: { value in
            guard let date = calendar.date(byAdding: .day, value: value, to: start) else { return false }
            return calendar.component(.weekday, from: date) == weekday
        }) else { return nil }
        return calendar.date(byAdding: .day, value: offset, to: start)
    }

    private static func captures(_ pattern: String, in value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]), let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)), match.range.location != NSNotFound else { return nil }
        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else { return "" }
            return String(value[swiftRange])
        }
    }

    private static func spread(_ count: Int, _ days: [Date]) -> [Date] {
        guard count > 0, !days.isEmpty else { return [] }
        if count == 1 { return [days[0]] }
        return (0..<count).map { days[Int((Double($0) * Double(days.count - 1) / Double(count - 1)).rounded())] }
    }
}

enum QuickEntryPersistenceError: Error, LocalizedError {
    case invalidDraft, duplicate
    var errorDescription: String? { self == .invalidDraft ? String(localized: "quickEntry.error.invalidDraft") : String(localized: "quickEntry.error.duplicate") }
}

@MainActor
enum QuickEntryPersistenceService {
    @discardableResult
    static func confirm(_ draft: QuickEntryDraft, courses: [Course], rules: [StudyScheduleRule], plannedWorkouts: [PlannedWorkoutSession], studyTasks: [StudyTask] = [], calendarEntries: [CalendarEntry] = [], context: ModelContext, calendar: Calendar = .current, now: Date = .now) throws -> Int {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, (0...1_439).contains(draft.startMinutes), (10...720).contains(draft.durationMinutes) else { throw QuickEntryPersistenceError.invalidDraft }
        switch draft.kind {
        case .weeklyLesson:
            guard let weekday = draft.weekday, (1...7).contains(weekday), let end = draft.effectiveEnd, calendar.startOfDay(for: end) >= calendar.startOfDay(for: draft.effectiveStart) else { throw QuickEntryPersistenceError.invalidDraft }
            let course = courses.first { $0.name.compare(title, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")) == .orderedSame } ?? Course(name: title, semesterStart: calendar.startOfDay(for: draft.effectiveStart), semesterEnd: calendar.startOfDay(for: end))
            if !courses.contains(where: { $0.id == course.id }) { context.insert(course) }
            let newStart = calendar.startOfDay(for: draft.effectiveStart), newEnd = calendar.startOfDay(for: end)
            guard !rules.contains(where: { $0.courseID == course.id && $0.isActive && $0.weekday == weekday && $0.startMinutes == draft.startMinutes && calendar.startOfDay(for: $0.effectiveStart) <= newEnd && ($0.effectiveEnd == nil || calendar.startOfDay(for: $0.effectiveEnd!) >= newStart) }) else { throw QuickEntryPersistenceError.duplicate }
            context.insert(StudyScheduleRule(courseID: course.id, weekday: weekday, startMinutes: draft.startMinutes, durationMinutes: draft.durationMinutes, effectiveStart: newStart, effectiveEnd: newEnd, createdAt: now, updatedAt: now))
            course.semesterStart = course.semesterStart ?? newStart
            course.semesterEnd = course.semesterEnd ?? newEnd
            course.updatedAt = now
        case .weeklyGym:
            let dates = draft.occurrenceDates.sorted()
            guard !dates.isEmpty, Set(dates.map { Int64($0.timeIntervalSince1970) }).count == dates.count, dates.allSatisfy({ $0 >= draft.effectiveStart }) else { throw QuickEntryPersistenceError.invalidDraft }
            guard !dates.contains(where: { date in plannedWorkouts.contains { abs($0.date.timeIntervalSince(date)) < 60 } }) else { throw QuickEntryPersistenceError.duplicate }
            dates.forEach { context.insert(PlannedWorkoutSession(date: $0, note: title, createdAt: now, updatedAt: now)) }
        case .studyTask:
            guard !studyTasks.contains(where: { $0.status != .cancelled && $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame && $0.dueDate.map { abs($0.timeIntervalSince(draft.effectiveStart)) < 60 } == true }) else { throw QuickEntryPersistenceError.duplicate }
            context.insert(StudyTask(title: title, dueDate: draft.effectiveStart, estimatedMinutes: draft.durationMinutes, createdAt: now, updatedAt: now))
        case .calendarTask, .calendarEvent:
            guard let end = draft.effectiveEnd, end > draft.effectiveStart, !calendarEntries.contains(where: { $0.title.localizedCaseInsensitiveCompare(title) == .orderedSame && abs($0.startDate.timeIntervalSince(draft.effectiveStart)) < 60 }) else { throw QuickEntryPersistenceError.duplicate }
            context.insert(CalendarEntry(title: title, startDate: draft.effectiveStart, endDate: end, kind: draft.kind == .calendarTask ? .task : .event, createdAt: now, updatedAt: now))
        case .gymSession:
            guard !plannedWorkouts.contains(where: { abs($0.date.timeIntervalSince(draft.effectiveStart)) < 60 }) else { throw QuickEntryPersistenceError.duplicate }
            context.insert(PlannedWorkoutSession(date: draft.effectiveStart, note: title, createdAt: now, updatedAt: now))
        }
        try context.save()
        return draft.kind == .weeklyGym ? draft.occurrenceDates.count : 1
    }
}
