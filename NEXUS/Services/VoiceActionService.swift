import Foundation
import SwiftData

enum VoiceActionVerb: String, Codable, CaseIterable, Identifiable {
    case create, edit, cancel
    var id: String { rawValue }
    var titleKey: String { "voice.action.verb.\(rawValue)" }
}

enum VoiceActionKind: String, Codable, CaseIterable, Identifiable {
    case studyTask, studyCourse, weeklyLesson
    case organizationTask, organizationProject
    case calendarEvent, calendarTask, calendarReminder
    case gymSession
    case financeExpense, financeIncome
    case note

    var id: String { rawValue }
    var titleKey: String { "voice.action.kind.\(rawValue)" }
    var owner: AppRoute {
        switch self {
        case .studyTask, .studyCourse, .weeklyLesson: .study
        case .organizationTask, .organizationProject: .organization
        case .calendarEvent, .calendarTask, .calendarReminder: .calendar
        case .gymSession: .gym
        case .financeExpense, .financeIncome: .finance
        case .note: .notes
        }
    }
}

/// A transient, user-editable proposal. It is deliberately not a SwiftData
/// model: recognition or remote interpretation can only fill this value.
struct VoiceActionDraft: Identifiable, Equatable, Codable {
    var id = UUID()
    var verb: VoiceActionVerb = .create
    var kind: VoiceActionKind
    var title: String
    var details: String = ""
    var startDate: Date?
    var endDate: Date?
    var dueDate: Date?
    var weekday: Int?
    var durationMinutes: Int = 60
    var recurrenceEnd: Date?
    var courseName: String = ""
    var projectName: String = ""
    var amountMinorUnits: Int?
    var currencyCode: String = "TRY"
    var targetRecordID: UUID?
    var targetOriginalTitle: String = ""
    var originalText: String
    var interpretationSource: VoiceActionInterpretationSource = .local
    var keepConflict: Bool = false

    var sendsLocalData: Bool { interpretationSource == .remote }
    var exactFieldLines: [String] {
        var lines = [
            "İşlem: \(String(localized: String.LocalizationValue(verb.titleKey)))",
            "Tür: \(String(localized: String.LocalizationValue(kind.titleKey)))",
            "Başlık: \(title)"
        ]
        if !details.isEmpty { lines.append("Ayrıntı: \(details)") }
        if let startDate { lines.append("Başlangıç: \(startDate.formatted(date: .abbreviated, time: .shortened))") }
        if let endDate { lines.append("Bitiş: \(endDate.formatted(date: .abbreviated, time: .shortened))") }
        if let dueDate { lines.append("Son tarih: \(dueDate.formatted(date: .abbreviated, time: .shortened))") }
        if let weekday { lines.append("Tekrar günü: \(Self.weekdayName(weekday))") }
        if let recurrenceEnd { lines.append("Tekrar bitişi: \(recurrenceEnd.formatted(date: .abbreviated, time: .omitted))") }
        if durationMinutes > 0 { lines.append("Süre: \(durationMinutes) dakika") }
        if !courseName.isEmpty { lines.append("Ders: \(courseName)") }
        if !projectName.isEmpty { lines.append("Proje: \(projectName)") }
        if let amountMinorUnits { lines.append("Tutar: \(Double(amountMinorUnits) / 100) \(currencyCode)") }
        if !targetOriginalTitle.isEmpty { lines.append("Değiştirilecek kayıt: \(targetOriginalTitle)") }
        return lines
    }

    var spokenPreview: String {
        String(localized: "voice.action.preview.spokenPrefix") + " " + exactFieldLines.joined(separator: ". ") + ". " + String(localized: "voice.action.preview.spokenConfirm")
    }

    private static func weekdayName(_ value: Int) -> String {
        let names = Calendar.current.weekdaySymbols
        return names.indices.contains(value - 1) ? names[value - 1] : "\(value)"
    }
}

enum VoiceActionInterpretationSource: String, Codable, Equatable { case local, remote }

enum VoiceActionParseResult: Equatable {
    case draft(VoiceActionDraft)
    case clarification(String)
    case unsupported
}

enum VoiceActionControlIntent: Equatable {
    case confirm, cancel, undo, keepConflict, findAnotherTime
    case correction(VoiceActionCorrection)
}

enum VoiceActionCorrection: Equatable {
    case title(String), date(Date), time(hour: Int, minute: Int), duration(Int)
}

enum VoiceActionSpeechControl {
    private static let turkishConfirm = ["onayla", "evet", "kaydet", "tamam onayla"]
    private static let arabicConfirm = ["تأكيد", "تاكيد", "نعم", "أكد", "اكد"]
    private static let turkishCancel = ["iptal", "vazgeç", "vazgec", "taslağı iptal et", "taslagi iptal et"]
    private static let arabicCancel = ["إلغاء", "الغاء", "ألغي", "الغي", "لا"]

    static func parse(_ input: String, referenceDate: Date = .now, calendar: Calendar = .current) -> VoiceActionControlIntent? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = VoiceCommandParser.normalized(raw)
        if turkishConfirm.contains(text) || arabicConfirm.contains(raw) { return .confirm }
        if turkishCancel.contains(text) || arabicCancel.contains(raw) { return .cancel }
        if ["geri al", "son işlemi geri al", "son islemi geri al"].contains(text) || ["تراجع", "تراجع عن آخر عملية", "ارجع آخر عملية"].contains(raw) { return .undo }
        if text == "yine de kaydet" || text == "çakışmaya rağmen kaydet" || raw == "احفظ على أي حال" { return .keepConflict }
        if text == "başka zaman bul" || text == "baska zaman bul" || raw == "ابحث عن وقت آخر" { return .findAnotherTime }
        if let title = capture(#"^(?:başlığı|basligi)\s+(.+?)\s+(?:yap|olarak değiştir|olarak degistir)$"#, in: raw)?.first { return .correction(.title(title)) }
        if let groups = capture(#"^(?:saati|saatini)\s+(\d{1,2})(?:[:\.]([0-5]\d))?\s+yap$"#, in: raw),
           let hour = Int(groups[0]), let minute = Int(groups[1].isEmpty ? "0" : groups[1]), hour < 24 { return .correction(.time(hour: hour, minute: minute)) }
        if let groups = capture(#"^(?:süreyi|sureyi)\s+(\d+)\s+dakika\s+yap$"#, in: raw), let minutes = Int(groups[0]), (10...720).contains(minutes) { return .correction(.duration(minutes)) }
        let normalized = VoiceCommandParser.normalized(raw)
        if normalized == "tarihi yarin yap", let date = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) { return .correction(.date(date)) }
        if normalized == "tarihi bugun yap" { return .correction(.date(calendar.startOfDay(for: referenceDate))) }
        return nil
    }

    private static func capture(_ pattern: String, in value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else { return "" }
            return String(value[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

enum LocalVoiceActionParser {
    static func parse(_ input: String, referenceDate: Date = .now, calendar: Calendar = .current) -> VoiceActionParseResult {
        let source = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return .unsupported }

        let stripped = source.replacingOccurrences(of: #"^(?:ekle|oluştur|olustur|kaydet)\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        if VoiceCommandParser.normalized(stripped).contains("hatirlatici") || VoiceCommandParser.normalized(stripped).contains("hatirlatma") {
            let eventText = stripped.replacingOccurrences(of: #"(?:hatırlatıcı|hatirlatıcı|hatırlatma|hatirlatma)$"#, with: "etkinlik", options: [.regularExpression, .caseInsensitive])
            if let quick = try? TurkishQuickEntryParser.parse(eventText, referenceDate: referenceDate, calendar: calendar) {
                var reminder = map(quick); reminder.kind = .calendarReminder; reminder.endDate = reminder.startDate; reminder.durationMinutes = 0; reminder.originalText = source
                return .draft(reminder)
            }
        }
        if let quick = try? TurkishQuickEntryParser.parse(stripped, referenceDate: referenceDate, calendar: calendar) {
            return .draft(map(quick))
        }
        if containsArabic(source) { return parseArabic(source, referenceDate: referenceDate, calendar: calendar) }

        if let g = capture(#"^(?:bir\s+)?not\s+ekle\s+(.+?)(?::\s*(.+))?$"#, in: source) {
            return .draft(.init(kind: .note, title: g[0], details: g[1], durationMinutes: 0, originalText: source))
        }
        if let g = capture(#"^(?:organizasyon\s+)?proje(?:si)?\s+ekle\s+(.+)$"#, in: source) {
            return .draft(.init(kind: .organizationProject, title: g[0], durationMinutes: 0, originalText: source))
        }
        if let g = capture(#"^(.+?)\s+projesine\s+(.+?)\s+(?:görev|gorev)(?:i)?\s+ekle$"#, in: source) {
            return .draft(.init(kind: .organizationTask, title: g[1], durationMinutes: 60, projectName: g[0], originalText: source))
        }
        if let g = capture(#"^(?:ders|kurs)\s+ekle\s+(.+)$"#, in: source) {
            return .draft(.init(kind: .studyCourse, title: g[0], durationMinutes: 0, originalText: source))
        }
        if let g = capture(#"^(?:ödev|odev|çalışma görevi|calisma gorevi)\s+ekle\s+(.+)$"#, in: source) {
            return .clarification(String(format: String(localized: "voice.action.clarify.dateTime"), g[0]))
        }
        if let g = capture(#"^(\d+(?:[\.,]\d{1,2})?)\s*(?:tl|try|lira)\s+(.+?)\s+(gider|harcama|gelir)\s+ekle$"#, in: source),
           let amount = Double(g[0].replacingOccurrences(of: ",", with: ".")), amount > 0 {
            let kind: VoiceActionKind = VoiceCommandParser.normalized(g[2]).contains("gelir") ? .financeIncome : .financeExpense
            return .draft(.init(kind: kind, title: g[1], startDate: referenceDate, durationMinutes: 0, amountMinorUnits: Int((amount * 100).rounded()), originalText: source))
        }
        if let g = capture(#"^(.+?)\s+(?:adlı|adli)\s+(ödev|odev|organizasyon görevi|organizasyon gorevi|takvim görevi|takvim gorevi|etkinlik|spor)\s+kaydını\s+yarına\s+taşı$"#, in: source) {
            let kind: VoiceActionKind = switch VoiceCommandParser.normalized(g[1]) {
            case let value where value.contains("organizasyon"): .organizationTask
            case let value where value.contains("takvim"): .calendarTask
            case let value where value.contains("etkinlik"): .calendarEvent
            case let value where value.contains("spor"): .gymSession
            default: .studyTask
            }
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate))!
            return .draft(.init(verb: .edit, kind: kind, title: g[0], startDate: tomorrow, dueDate: tomorrow, durationMinutes: 60, targetOriginalTitle: g[0], originalText: source))
        }
        if let g = capture(#"^(.+?)\s+(?:adlı|adli)\s+(ödev|odev|organizasyon görevi|organizasyon gorevi)\s+kaydını\s+iptal\s+et$"#, in: source) {
            let kind: VoiceActionKind = switch VoiceCommandParser.normalized(g[1]) {
            case let value where value.contains("organizasyon"): .organizationTask
            default: .studyTask
            }
            return .draft(.init(verb: .cancel, kind: kind, title: g[0], durationMinutes: 0, targetOriginalTitle: g[0], originalText: source))
        }
        if VoiceCommandParser.normalized(source).contains("ekle") || VoiceCommandParser.normalized(source).contains("olustur") {
            return .clarification(String(localized: "voice.action.clarify.unsupportedFields"))
        }
        return .unsupported
    }

    static func applying(_ correction: VoiceActionCorrection, to draft: VoiceActionDraft, calendar: Calendar = .current) -> VoiceActionDraft {
        var value = draft
        switch correction {
        case .title(let title): value.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        case .date(let day):
            let source = value.startDate ?? value.dueDate ?? day
            let time = calendar.dateComponents([.hour, .minute], from: source)
            let changed = calendar.date(bySettingHour: time.hour ?? 17, minute: time.minute ?? 0, second: 0, of: day) ?? day
            if value.startDate != nil { value.startDate = changed; value.endDate = calendar.date(byAdding: .minute, value: value.durationMinutes, to: changed) }
            if value.dueDate != nil || value.kind == .studyTask || value.kind == .organizationTask { value.dueDate = changed }
        case .time(let hour, let minute):
            if let start = value.startDate {
                value.startDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
                value.endDate = value.startDate.flatMap { calendar.date(byAdding: .minute, value: value.durationMinutes, to: $0) }
            } else if let due = value.dueDate { value.dueDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: due) }
        case .duration(let minutes):
            value.durationMinutes = minutes
            if let start = value.startDate { value.endDate = calendar.date(byAdding: .minute, value: minutes, to: start) }
        }
        value.keepConflict = false
        return value
    }

    private static func map(_ draft: QuickEntryDraft) -> VoiceActionDraft {
        let kind: VoiceActionKind = switch draft.kind {
        case .weeklyLesson: .weeklyLesson
        case .weeklyGym, .gymSession: .gymSession
        case .studyTask: .studyTask
        case .calendarTask: .calendarTask
        case .calendarEvent: .calendarEvent
        }
        let startDate: Date? = kind == .studyTask ? nil : (draft.kind == .weeklyGym ? draft.occurrenceDates.first : draft.effectiveStart)
        let endDate: Date? = kind == .studyTask ? nil : startDate.flatMap { Calendar.current.date(byAdding: .minute, value: draft.durationMinutes, to: $0) }
        return .init(kind: kind, title: draft.title, startDate: startDate, endDate: endDate,
                     dueDate: kind == .studyTask ? draft.effectiveStart : nil, weekday: draft.weekday,
                     durationMinutes: draft.durationMinutes, recurrenceEnd: draft.kind == .weeklyLesson ? draft.effectiveEnd : nil,
                     originalText: draft.originalText)
    }

    private static func parseArabic(_ source: String, referenceDate: Date, calendar: Calendar) -> VoiceActionParseResult {
        let normalized = arabicDigits(source).replacingOccurrences(of: "،", with: " ")
        let day: Date? = {
            if normalized.contains("بكرا") || normalized.contains("غدا") || normalized.contains("غداً") { return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) }
            if normalized.contains("اليوم") { return calendar.startOfDay(for: referenceDate) }
            return nil
        }()
        let time = arabicTime(normalized)
        let timed = day.flatMap { day in time.flatMap { calendar.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: day) } }

        if let g = capture(#"(?:أضف|اضف)?\s*(?:عندي\s+)?درس\s+(.+)$"#, in: normalized) {
            let title = cleanArabicTitle(g[0])
            guard let timed else { return .clarification(String(localized: "voice.action.clarify.arabicLesson")) }
            return .draft(.init(kind: .weeklyLesson, title: title, startDate: timed, endDate: calendar.date(byAdding: .minute, value: 50, to: timed), weekday: calendar.component(.weekday, from: timed), durationMinutes: 50, recurrenceEnd: calendar.startOfDay(for: timed), originalText: source))
        }
        if normalized.contains("نادي") || normalized.contains("رياضة") || normalized.contains("تمرين") {
            guard let timed else { return .clarification(String(localized: "voice.action.clarify.arabicGym")) }
            return .draft(.init(kind: .gymSession, title: String(localized: "voice.action.defaultGymTitle"), startDate: timed, endDate: calendar.date(byAdding: .minute, value: 60, to: timed), durationMinutes: 60, originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+(?:واجب|مهمة\s+دراسة)\s+(.+)$"#, in: normalized) {
            guard let timed else { return .clarification(String(localized: "voice.action.clarify.arabicTask")) }
            return .draft(.init(kind: .studyTask, title: cleanArabicTitle(g[0]), dueDate: timed, durationMinutes: 60, originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+ملاحظة\s+(.+)$"#, in: normalized) {
            return .draft(.init(kind: .note, title: cleanArabicTitle(g[0]), durationMinutes: 0, originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+مشروع\s+(.+)$"#, in: normalized) {
            return .draft(.init(kind: .organizationProject, title: cleanArabicTitle(g[0]), durationMinutes: 0, originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+(?:مهمة|مهمة تنظيم)\s+(.+?)\s+(?:لمشروع|في مشروع)\s+(.+)$"#, in: normalized) {
            return .draft(.init(kind: .organizationTask, title: cleanArabicTitle(g[0]), durationMinutes: 60, projectName: cleanArabicTitle(g[1]), originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+(?:حدث|موعد)\s+(.+)$"#, in: normalized) {
            guard let timed else { return .clarification(String(localized: "voice.action.clarify.dateTimeArabic")) }
            return .draft(.init(kind: .calendarEvent, title: cleanArabicTitle(g[0]), startDate: timed, endDate: calendar.date(byAdding: .minute, value: 60, to: timed), durationMinutes: 60, originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+تذكير\s+(.+)$"#, in: normalized) {
            guard let timed else { return .clarification(String(localized: "voice.action.clarify.dateTimeArabic")) }
            return .draft(.init(kind: .calendarReminder, title: cleanArabicTitle(g[0]), startDate: timed, endDate: timed, durationMinutes: 0, originalText: source))
        }
        if let g = capture(#"(?:أضف|اضف)\s+(مصروف|دخل)\s+(\d+(?:[\.,]\d{1,2})?)\s*(?:ليرة|لير|try)?\s*(.+)$"#, in: normalized),
           let amount = Double(g[1].replacingOccurrences(of: ",", with: ".")), amount > 0 {
            return .draft(.init(kind: g[0] == "دخل" ? .financeIncome : .financeExpense, title: cleanArabicTitle(g[2]), startDate: referenceDate, durationMinutes: 0, amountMinorUnits: Int((amount * 100).rounded()), originalText: source))
        }
        if normalized.contains("أضف") || normalized.contains("اضف") || normalized.contains("حط") {
            return .clarification(String(localized: "voice.action.clarify.unsupportedFieldsArabic"))
        }
        return .unsupported
    }

    private static func arabicTime(_ value: String) -> (hour: Int, minute: Int)? {
        guard let g = capture(#"الساعة\s+(\d{1,2}|واحدة|الواحدة|اثنتين|اثنين|الثانية|ثلاثة|الثالثة|أربعة|اربعة|الرابعة|خمسة|الخامسة|ستة|السادسة|سبعة|السابعة|ثمانية|الثامنة|تسعة|التاسعة|عشرة|العاشرة|احد عشر|الحادية عشر|اثنا عشر|الثانية عشر)(?::([0-5]\d))?"#, in: value) else { return nil }
        let words = ["واحدة": 1, "الواحدة": 1, "اثنتين": 2, "اثنين": 2, "الثانية": 2, "ثلاثة": 3, "الثالثة": 3, "أربعة": 4, "اربعة": 4, "الرابعة": 4, "خمسة": 5, "الخامسة": 5, "ستة": 6, "السادسة": 6, "سبعة": 7, "السابعة": 7, "ثمانية": 8, "الثامنة": 8, "تسعة": 9, "التاسعة": 9, "عشرة": 10, "العاشرة": 10, "احد عشر": 11, "الحادية عشر": 11, "اثنا عشر": 12, "الثانية عشر": 12]
        guard let hour = Int(g[0]) ?? words[g[0]], (0...23).contains(hour), let minute = Int(g[1].isEmpty ? "0" : g[1]) else { return nil }
        return (hour, minute)
    }

    private static func cleanArabicTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: #"\s*(?:بكرا|غدا|غداً|اليوم)?\s*الساعة\s+.+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func arabicDigits(_ value: String) -> String {
        let map: [Character: Character] = ["٠":"0", "١":"1", "٢":"2", "٣":"3", "٤":"4", "٥":"5", "٦":"6", "٧":"7", "٨":"8", "٩":"9"]
        return String(value.map { map[$0] ?? $0 })
    }

    private static func containsArabic(_ value: String) -> Bool { value.range(of: #"[\u{0600}-\u{06FF}]"#, options: .regularExpression) != nil }

    private static func capture(_ pattern: String, in value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: value) else { return "" }
            return String(value[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

struct VoiceActionConflict: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let suggestedStart: Date?
}

enum VoiceActionValidationResult: Equatable { case valid, conflict(VoiceActionConflict) }

enum VoiceActionPersistenceError: LocalizedError {
    case invalidDraft, ambiguousTarget, missingTarget, missingProject, duplicate, unresolvedConflict, nothingToUndo
    var errorDescription: String? {
        switch self {
        case .invalidDraft: String(localized: "voice.action.error.invalid")
        case .ambiguousTarget: String(localized: "voice.action.error.ambiguousTarget")
        case .missingTarget: String(localized: "voice.action.error.missingTarget")
        case .missingProject: String(localized: "voice.action.error.missingProject")
        case .duplicate: String(localized: "quickEntry.error.duplicate")
        case .unresolvedConflict: String(localized: "voice.action.error.conflict")
        case .nothingToUndo: String(localized: "voice.action.error.nothingToUndo")
        }
    }
}

struct VoiceActionUndoToken: Equatable {
    enum Operation: Equatable { case created(kind: VoiceActionKind, ids: [UUID]), changed(kind: VoiceActionKind, id: UUID, snapshot: VoiceActionSnapshot) }
    let operation: Operation
    let summary: String
}

struct VoiceActionSnapshot: Equatable {
    let title: String
    let date: Date?
    let status: String?
}

@MainActor
enum VoiceActionPersistenceService {
    static func prepare(_ draft: VoiceActionDraft, context: ModelContext, calendar: Calendar = .current) throws -> (VoiceActionDraft, VoiceActionValidationResult) {
        var value = draft
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.title.isEmpty, value.durationMinutes >= 0, value.durationMinutes <= 720 else { throw VoiceActionPersistenceError.invalidDraft }
        if value.verb != .create { value.targetRecordID = try resolveTarget(value, context: context) }
        if value.kind == .organizationTask && value.verb == .create {
            let projects = try context.fetch(FetchDescriptor<ProjectRecord>()).filter { !$0.isArchived }
            let matches = projects.filter { same($0.title, value.projectName) }
            if value.projectName.isEmpty, projects.count == 1 { value.projectName = projects[0].title }
            else if matches.count != 1 { throw VoiceActionPersistenceError.missingProject }
        }
        try validateFields(value)
        if value.verb == .create, try isDuplicate(value, context: context) { throw VoiceActionPersistenceError.duplicate }
        if let conflict = try conflict(for: value, context: context, calendar: calendar), !value.keepConflict { return (value, .conflict(conflict)) }
        return (value, .valid)
    }

    static func confirm(_ draft: VoiceActionDraft, context: ModelContext, calendar: Calendar = .current, now: Date = .now) throws -> VoiceActionUndoToken {
        let (value, result) = try prepare(draft, context: context, calendar: calendar)
        if case .conflict = result { throw VoiceActionPersistenceError.unresolvedConflict }
        switch value.verb {
        case .create: return try create(value, context: context, calendar: calendar, now: now)
        case .edit: return try edit(value, context: context, now: now)
        case .cancel: return try cancel(value, context: context, now: now)
        }
    }

    static func rescheduled(_ draft: VoiceActionDraft, to date: Date, calendar: Calendar = .current) -> VoiceActionDraft {
        var value = draft
        let duration = value.durationMinutes
        if value.startDate != nil { value.startDate = date; value.endDate = calendar.date(byAdding: .minute, value: duration, to: date) }
        if value.dueDate != nil { value.dueDate = date }
        if value.kind == .weeklyLesson { value.weekday = calendar.component(.weekday, from: date) }
        value.keepConflict = false
        return value
    }

    static func undo(_ token: VoiceActionUndoToken, context: ModelContext) throws {
        switch token.operation {
        case .created(let kind, let ids): try deleteCreated(kind: kind, ids: ids, context: context)
        case .changed(let kind, let id, let snapshot): try restore(kind: kind, id: id, snapshot: snapshot, context: context)
        }
        try context.save()
    }

    private static func validateFields(_ value: VoiceActionDraft) throws {
        switch value.kind {
        case .weeklyLesson:
            guard let start = value.startDate, let end = value.recurrenceEnd ?? value.endDate, end >= Calendar.current.startOfDay(for: start),
                  let weekday = value.weekday, (1...7).contains(weekday), value.durationMinutes >= 10 else { throw VoiceActionPersistenceError.invalidDraft }
        case .studyTask:
            guard value.dueDate != nil || value.verb == .cancel else { throw VoiceActionPersistenceError.invalidDraft }
        case .organizationTask: break
        case .calendarEvent, .calendarTask:
            guard let start = value.startDate, let end = value.endDate, end >= start else { throw VoiceActionPersistenceError.invalidDraft }
        case .calendarReminder:
            guard value.startDate != nil else { throw VoiceActionPersistenceError.invalidDraft }
        case .gymSession:
            guard value.startDate != nil, value.durationMinutes >= 10 else { throw VoiceActionPersistenceError.invalidDraft }
        case .financeExpense, .financeIncome:
            guard let amount = value.amountMinorUnits, amount > 0 else { throw VoiceActionPersistenceError.invalidDraft }
        case .studyCourse, .organizationProject, .note: break
        }
    }

    private static func conflict(for value: VoiceActionDraft, context: ModelContext, calendar: Calendar) throws -> VoiceActionConflict? {
        guard value.verb != .cancel else { return nil }
        if value.kind == .weeklyLesson, let weekday = value.weekday {
            let existing = try context.fetch(FetchDescriptor<StudyScheduleRule>()).filter(\.isActive)
            let proposed = ScheduleSlot(id: value.targetRecordID ?? value.id, weekday: weekday, startMinutes: minutes(value.startDate, calendar), durationMinutes: value.durationMinutes)
            let slots = existing.map { ScheduleSlot(id: $0.id, weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes) }
            guard !ScheduleConflictService.conflicts(proposed, with: slots).isEmpty else { return nil }
            let suggested = ScheduleConflictService.nextAvailableStart(for: proposed, existing: slots).flatMap { start in
                value.startDate.flatMap { calendar.date(bySettingHour: start / 60, minute: start % 60, second: 0, of: $0) }
            }
            return .init(message: String(localized: "voice.action.conflict.lesson"), suggestedStart: suggested)
        }
        guard let start = value.startDate, value.kind == .calendarEvent || value.kind == .calendarTask || value.kind == .gymSession else { return nil }
        let end = value.endDate ?? calendar.date(byAdding: .minute, value: max(value.durationMinutes, 10), to: start)!
        let events = try context.fetch(FetchDescriptor<CalendarEntry>()).filter { $0.id != value.targetRecordID && start < $0.endDate && $0.startDate < end }
        let workouts = try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).filter { $0.id != value.targetRecordID && abs($0.date.timeIntervalSince(start)) < Double(max(value.durationMinutes, 30) * 60) }
        guard !events.isEmpty || !workouts.isEmpty else { return nil }
        return .init(message: String(localized: "voice.action.conflict.timed"), suggestedStart: calendar.date(byAdding: .minute, value: 30, to: end))
    }

    private static func isDuplicate(_ value: VoiceActionDraft, context: ModelContext) throws -> Bool {
        switch value.kind {
        case .studyTask:
            return try context.fetch(FetchDescriptor<StudyTask>()).contains { same($0.title, value.title) && datesNear($0.dueDate, value.dueDate) && $0.status != .cancelled }
        case .studyCourse:
            return try context.fetch(FetchDescriptor<Course>()).contains { same($0.name, value.title) }
        case .weeklyLesson:
            guard let weekday = value.weekday, let start = value.startDate else { return false }
            let courses = try context.fetch(FetchDescriptor<Course>())
            let ids = Set(courses.filter { same($0.name, value.courseName.isEmpty ? value.title : value.courseName) }.map(\.id))
            return try context.fetch(FetchDescriptor<StudyScheduleRule>()).contains { ids.contains($0.courseID) && $0.weekday == weekday && $0.startMinutes == minutes(start, .current) && $0.isActive }
        case .organizationProject:
            return try context.fetch(FetchDescriptor<ProjectRecord>()).contains { same($0.title, value.title) && !$0.isArchived }
        case .organizationTask:
            let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
            guard let project = projects.first(where: { same($0.title, value.projectName) }) else { return false }
            return try context.fetch(FetchDescriptor<OrganizationTask>()).contains { $0.projectID == project.id && same($0.title, value.title) && datesNear($0.dueDate, value.dueDate) && $0.status != .cancelled }
        case .calendarEvent, .calendarTask, .calendarReminder:
            return try context.fetch(FetchDescriptor<CalendarEntry>()).contains { same($0.title, value.title) && datesNear($0.startDate, value.startDate) }
        case .gymSession:
            return try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).contains { same($0.note, value.title) && datesNear($0.date, value.startDate) }
        case .financeExpense, .financeIncome:
            return try context.fetch(FetchDescriptor<FinanceEntry>()).contains { same($0.title, value.title) && $0.amountMinorUnits == value.amountMinorUnits && datesNear($0.date, value.startDate) }
        case .note: return false
        }
    }

    private static func create(_ value: VoiceActionDraft, context: ModelContext, calendar: Calendar, now: Date) throws -> VoiceActionUndoToken {
        var ids: [UUID] = []
        switch value.kind {
        case .studyTask:
            let item = StudyTask(title: value.title, details: value.details, dueDate: value.dueDate, estimatedMinutes: value.durationMinutes, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .studyCourse:
            let item = Course(name: value.title, instructor: value.details, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .weeklyLesson:
            guard let weekday = value.weekday, let start = value.startDate, let end = value.recurrenceEnd ?? value.endDate else { throw VoiceActionPersistenceError.invalidDraft }
            let existingCourses = try context.fetch(FetchDescriptor<Course>())
            let existingCourse = existingCourses.first { same($0.name, value.courseName.isEmpty ? value.title : value.courseName) }
            let course = existingCourse ?? Course(name: value.courseName.isEmpty ? value.title : value.courseName, semesterStart: calendar.startOfDay(for: start), semesterEnd: calendar.startOfDay(for: end), createdAt: now, updatedAt: now)
            if existingCourse == nil { context.insert(course); ids.append(course.id) }
            let rule = StudyScheduleRule(courseID: course.id, weekday: weekday, startMinutes: minutes(start, calendar), durationMinutes: value.durationMinutes, effectiveStart: calendar.startOfDay(for: start), effectiveEnd: calendar.startOfDay(for: end), locationOverride: value.details, createdAt: now, updatedAt: now)
            context.insert(rule); ids.insert(rule.id, at: 0)
        case .organizationProject:
            let item = ProjectRecord(title: value.title, details: value.details, dueDate: value.dueDate, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .organizationTask:
            let projects = try context.fetch(FetchDescriptor<ProjectRecord>())
            guard let project = projects.first(where: { same($0.title, value.projectName) }) else { throw VoiceActionPersistenceError.missingProject }
            let item = OrganizationTask(projectID: project.id, title: value.title, details: value.details, dueDate: value.dueDate, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .calendarEvent, .calendarTask, .calendarReminder:
            guard let start = value.startDate else { throw VoiceActionPersistenceError.invalidDraft }
            let kind: CalendarEntryKind = value.kind == .calendarEvent ? .event : value.kind == .calendarTask ? .task : .reminder
            let item = CalendarEntry(title: value.title, details: value.details, startDate: start, endDate: value.endDate ?? start, kind: kind, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .gymSession:
            guard let date = value.startDate else { throw VoiceActionPersistenceError.invalidDraft }
            let item = PlannedWorkoutSession(date: date, note: value.title, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .financeExpense, .financeIncome:
            guard let amount = value.amountMinorUnits else { throw VoiceActionPersistenceError.invalidDraft }
            let item = FinanceEntry(date: value.startDate ?? now, title: value.title, amountMinorUnits: amount, currencyCode: value.currencyCode, type: value.kind == .financeIncome ? .income : .expense, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        case .note:
            let item = NexusNote(title: value.title, body: value.details, createdAt: now, updatedAt: now); context.insert(item); ids = [item.id]
        }
        try context.save()
        return .init(operation: .created(kind: value.kind, ids: ids), summary: value.title)
    }

    private static func edit(_ value: VoiceActionDraft, context: ModelContext, now: Date) throws -> VoiceActionUndoToken {
        guard let id = value.targetRecordID else { throw VoiceActionPersistenceError.missingTarget }
        let snapshot: VoiceActionSnapshot
        switch value.kind {
        case .studyTask:
            guard let item = try context.fetch(FetchDescriptor<StudyTask>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            snapshot = .init(title: item.title, date: item.dueDate, status: item.statusRaw); item.title = value.title; item.dueDate = value.dueDate; item.updatedAt = now
        case .organizationTask:
            guard let item = try context.fetch(FetchDescriptor<OrganizationTask>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            snapshot = .init(title: item.title, date: item.dueDate, status: item.statusRaw); item.title = value.title; item.dueDate = value.dueDate; item.updatedAt = now
        case .calendarTask, .calendarEvent, .calendarReminder:
            guard let item = try context.fetch(FetchDescriptor<CalendarEntry>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            snapshot = .init(title: item.title, date: item.startDate, status: item.isCompleted ? "1" : "0"); item.title = value.title
            if let date = value.startDate { let duration = item.endDate.timeIntervalSince(item.startDate); item.startDate = date; item.endDate = date.addingTimeInterval(max(duration, 0)) }; item.updatedAt = now
        case .gymSession:
            guard let item = try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            snapshot = .init(title: item.note, date: item.date, status: item.isCompleted ? "1" : "0"); item.note = value.title; if let date = value.startDate { item.date = date }; item.updatedAt = now
        default: throw VoiceActionPersistenceError.invalidDraft
        }
        try context.save()
        return .init(operation: .changed(kind: value.kind, id: id, snapshot: snapshot), summary: value.title)
    }

    private static func cancel(_ value: VoiceActionDraft, context: ModelContext, now: Date) throws -> VoiceActionUndoToken {
        guard let id = value.targetRecordID else { throw VoiceActionPersistenceError.missingTarget }
        let snapshot: VoiceActionSnapshot
        switch value.kind {
        case .studyTask:
            guard let item = try context.fetch(FetchDescriptor<StudyTask>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            snapshot = .init(title: item.title, date: item.dueDate, status: item.statusRaw); item.status = .cancelled; item.updatedAt = now
        case .organizationTask:
            guard let item = try context.fetch(FetchDescriptor<OrganizationTask>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            snapshot = .init(title: item.title, date: item.dueDate, status: item.statusRaw); item.status = .cancelled; item.updatedAt = now
        default: throw VoiceActionPersistenceError.invalidDraft
        }
        try context.save()
        return .init(operation: .changed(kind: value.kind, id: id, snapshot: snapshot), summary: value.title)
    }

    private static func resolveTarget(_ value: VoiceActionDraft, context: ModelContext) throws -> UUID {
        if let id = value.targetRecordID { return id }
        let title = value.targetOriginalTitle.isEmpty ? value.title : value.targetOriginalTitle
        let ids: [UUID] = switch value.kind {
        case .studyTask: try context.fetch(FetchDescriptor<StudyTask>()).filter { same($0.title, title) }.map(\.id)
        case .organizationTask: try context.fetch(FetchDescriptor<OrganizationTask>()).filter { same($0.title, title) }.map(\.id)
        case .calendarTask, .calendarEvent, .calendarReminder: try context.fetch(FetchDescriptor<CalendarEntry>()).filter { same($0.title, title) }.map(\.id)
        case .gymSession: try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).filter { same($0.note, title) }.map(\.id)
        default: []
        }
        guard !ids.isEmpty else { throw VoiceActionPersistenceError.missingTarget }
        guard ids.count == 1 else { throw VoiceActionPersistenceError.ambiguousTarget }
        return ids[0]
    }

    private static func deleteCreated(kind: VoiceActionKind, ids: [UUID], context: ModelContext) throws {
        let set = Set(ids)
        switch kind {
        case .studyTask: try context.fetch(FetchDescriptor<StudyTask>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .studyCourse: try context.fetch(FetchDescriptor<Course>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .weeklyLesson:
            try context.fetch(FetchDescriptor<StudyScheduleRule>()).filter { set.contains($0.id) }.forEach(context.delete)
            try context.fetch(FetchDescriptor<Course>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .organizationTask: try context.fetch(FetchDescriptor<OrganizationTask>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .organizationProject: try context.fetch(FetchDescriptor<ProjectRecord>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .calendarEvent, .calendarTask, .calendarReminder: try context.fetch(FetchDescriptor<CalendarEntry>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .gymSession: try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .financeExpense, .financeIncome: try context.fetch(FetchDescriptor<FinanceEntry>()).filter { set.contains($0.id) }.forEach(context.delete)
        case .note: try context.fetch(FetchDescriptor<NexusNote>()).filter { set.contains($0.id) }.forEach(context.delete)
        }
    }

    private static func restore(kind: VoiceActionKind, id: UUID, snapshot: VoiceActionSnapshot, context: ModelContext) throws {
        switch kind {
        case .studyTask:
            guard let item = try context.fetch(FetchDescriptor<StudyTask>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            item.title = snapshot.title; item.dueDate = snapshot.date; if let raw = snapshot.status { item.statusRaw = raw }; item.updatedAt = .now
        case .organizationTask:
            guard let item = try context.fetch(FetchDescriptor<OrganizationTask>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            item.title = snapshot.title; item.dueDate = snapshot.date; if let raw = snapshot.status { item.statusRaw = raw }; item.updatedAt = .now
        case .calendarTask, .calendarEvent, .calendarReminder:
            guard let item = try context.fetch(FetchDescriptor<CalendarEntry>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            let duration = item.endDate.timeIntervalSince(item.startDate); item.title = snapshot.title; if let date = snapshot.date { item.startDate = date; item.endDate = date.addingTimeInterval(max(duration, 0)) }; item.isCompleted = snapshot.status == "1"; item.updatedAt = .now
        case .gymSession:
            guard let item = try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).first(where: { $0.id == id }) else { throw VoiceActionPersistenceError.missingTarget }
            item.note = snapshot.title; if let date = snapshot.date { item.date = date }; item.isCompleted = snapshot.status == "1"; item.updatedAt = .now
        default: throw VoiceActionPersistenceError.invalidDraft
        }
    }

    private static func minutes(_ date: Date?, _ calendar: Calendar) -> Int {
        guard let date else { return 0 }; let parts = calendar.dateComponents([.hour, .minute], from: date); return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
    private static func same(_ left: String, _ right: String) -> Bool { left.compare(right, options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR")) == .orderedSame }
    private static func datesNear(_ left: Date?, _ right: Date?) -> Bool {
        guard let left, let right else { return left == nil && right == nil }
        return abs(left.timeIntervalSince(right)) < 60
    }
}

struct VoiceDraftInterpretationConsent: Identifiable, Equatable {
    let id = UUID()
    let exactOutgoingText: String
}

protocol VoiceRemoteDraftInterpreting {
    func proposeAction(text: String, model: String, apiKey: String) async throws -> VoiceActionDraft
}

enum VoiceRemoteDraftRequestBuilder {
    static func makeBody(text: String, model: String) throws -> Data {
        let nullableString: [String: Any] = ["type": ["string", "null"]]
        let nullableInteger: [String: Any] = ["type": ["integer", "null"]]
        let parameters: [String: Any] = [
            "type": "object", "additionalProperties": false,
            "properties": [
                "kind": ["type": "string", "enum": VoiceActionKind.allCases.map(\.rawValue)],
                "title": ["type": "string"], "details": ["type": "string"],
                "startISO8601": nullableString, "endISO8601": nullableString, "dueISO8601": nullableString,
                "weekday": nullableInteger, "durationMinutes": ["type": "integer", "minimum": 0, "maximum": 720],
                "recurrenceEndISO8601": nullableString, "courseName": ["type": "string"], "projectName": ["type": "string"],
                "amountMinorUnits": nullableInteger, "currencyCode": ["type": "string"],
                "needsClarification": ["type": "boolean"], "clarificationQuestion": ["type": "string"]
            ],
            "required": ["kind", "title", "details", "startISO8601", "endISO8601", "dueISO8601", "weekday", "durationMinutes", "recurrenceEndISO8601", "courseName", "projectName", "amountMinorUnits", "currencyCode", "needsClarification", "clarificationQuestion"]
        ]
        let body: [String: Any] = [
            "model": model, "instructions": String(localized: "voice.action.remote.instructions"), "input": text,
            "store": false, "max_output_tokens": 500, "parallel_tool_calls": false,
            "tools": [["type": "function", "name": "propose_nexus_action", "description": "Return one inert NEXUS action draft. This function has no write capability.", "strict": true, "parameters": parameters]],
            "tool_choice": ["type": "function", "name": "propose_nexus_action"]
        ]
        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }
}
