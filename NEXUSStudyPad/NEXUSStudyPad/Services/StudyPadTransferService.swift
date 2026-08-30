import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum TransferSource: String, Codable { case studyPadV1, nexusMacV9 }
enum TransferDuplicatePolicy: String, CaseIterable, Identifiable {
    case skip, update
    var id: String { rawValue }
    var title: String { self == .skip ? "Aynı kimliği atla" : "Aynı kimliği güncelle" }
}

struct StudyPadTransfer: Codable {
    let format: String
    let schemaVersion: Int
    let createdAt: Date
    var courses: [CoursePayload]
    var scheduleRules: [SchedulePayload]
    var lectures: [LecturePayload]
    var notes: [NotePayload]
    var tasks: [TaskPayload]

    static let currentFormat = "nexus-study-pad-transfer"
    static let currentVersion = 2

    struct CoursePayload: Codable { let id: UUID; var name, code, instructor: String; var semesterWeekCount: Int? = nil; var createdAt, updatedAt: Date }
    struct SchedulePayload: Codable { let id, courseID: UUID; var weekday, startMinutes, durationMinutes: Int; var effectiveStart: Date; var effectiveEnd: Date?; var location: String; var isActive: Bool; var createdAt, updatedAt: Date }
    struct LecturePayload: Codable { let id: UUID; var courseID: UUID?; var title: String; var date: Date; var attendance, review, note: String; var weekNumber: Int? = nil; var lessonNumber: Int? = nil; var createdAt, updatedAt: Date }
    struct NotePayload: Codable { let id: UUID; var courseID, lectureID: UUID?; var title, body: String; var isPinned: Bool; var createdAt, updatedAt: Date }
    struct TaskPayload: Codable { let id: UUID; var courseID: UUID?; var title, details: String; var dueDate: Date?; var isCompleted: Bool; var createdAt, updatedAt: Date }
}

private struct MacBackupSubset: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let courses: [CourseRecord]
    let tasks: [TaskRecord]
    var notes: [NoteRecord]?
    var studyScheduleRules: [ScheduleRecord]?

    struct CourseRecord: Codable { let id: UUID; let name, code, instructor: String; let createdAt, updatedAt: Date }
    struct TaskRecord: Codable { let id: UUID; let title, details: String; let courseID: UUID?; let dueDate: Date?; let status: String; let completedAt: Date?; let createdAt, updatedAt: Date }
    struct NoteRecord: Codable { let id: UUID; let title, body: String; let isPinned: Bool; let createdAt, updatedAt: Date }
    struct ScheduleRecord: Codable { let id, courseID: UUID; let weekday, startMinutes, durationMinutes: Int; let effectiveStart: Date; let effectiveEnd: Date?; let locationOverride: String; let isActive: Bool; let createdAt, updatedAt: Date }
}

enum StudyPadTransferError: LocalizedError {
    case unreadable, unsupportedFormat, unsupportedVersion, duplicateIdentifiers, invalidRecord(String), invalidReference(String), noImportableData
    var errorDescription: String? {
        switch self {
        case .unreadable: "JSON dosyası okunamadı."
        case .unsupportedFormat: "Bu JSON, NEXUS StudyPad Transfer veya desteklenen NEXUS Mac yedeği değil."
        case .unsupportedVersion: "Bu aktarım sürümü desteklenmiyor."
        case .duplicateIdentifiers: "Dosyanın kendi içinde yinelenen kayıt kimlikleri var."
        case .invalidRecord(let message): "Geçersiz kayıt: \(message)"
        case .invalidReference(let message): "Geçersiz bağlantı: \(message)"
        case .noImportableData: "Dosyada içe aktarılabilir çalışma verisi yok."
        }
    }
}

struct PreparedTransfer {
    let source: TransferSource
    let pack: StudyPadTransfer
    let warnings: [String]
}

struct TransferPreview {
    let source: TransferSource
    let courseCount, scheduleCount, lectureCount, noteCount, taskCount: Int
    let duplicateCount: Int
    let warnings: [String]
    var total: Int { courseCount + scheduleCount + lectureCount + noteCount + taskCount }
}

struct TransferImportResult: Equatable {
    let inserted: Int
    let updated: Int
    let skipped: Int
}

@MainActor
enum StudyPadTransferService {
    static func decoder() -> JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
    static func encoder() -> JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; value.outputFormatting = [.prettyPrinted, .sortedKeys]; return value }

    static func prepare(data: Data) throws -> PreparedTransfer {
        let decoder = decoder()
        if let native = try? decoder.decode(StudyPadTransfer.self, from: data), native.format == StudyPadTransfer.currentFormat {
            guard (1...StudyPadTransfer.currentVersion).contains(native.schemaVersion) else { throw StudyPadTransferError.unsupportedVersion }
            let normalized = normalize(native)
            try validate(normalized)
            var warnings = ["PDF, PencilKit çizimleri ve ses dosyaları JSON paketine dahil değildir."]
            if native.schemaVersion == 1 { warnings.append("Eski v1 paketi 15 haftalık dönem ve 1. ders varsayımlarıyla güvenli biçimde yükseltildi.") }
            return PreparedTransfer(source: .studyPadV1, pack: normalized, warnings: warnings)
        }
        guard let mac = try? decoder.decode(MacBackupSubset.self, from: data) else { throw StudyPadTransferError.unsupportedFormat }
        guard (1...9).contains(mac.schemaVersion) else { throw StudyPadTransferError.unsupportedVersion }
        let pack = StudyPadTransfer(
            format: StudyPadTransfer.currentFormat, schemaVersion: StudyPadTransfer.currentVersion, createdAt: mac.createdAt,
            courses: mac.courses.map { .init(id: $0.id, name: $0.name, code: $0.code, instructor: $0.instructor, semesterWeekCount: 15, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            scheduleRules: (mac.studyScheduleRules ?? []).map { .init(id: $0.id, courseID: $0.courseID, weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes, effectiveStart: $0.effectiveStart, effectiveEnd: $0.effectiveEnd, location: $0.locationOverride, isActive: $0.isActive, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            lectures: [],
            notes: (mac.notes ?? []).map { .init(id: $0.id, courseID: nil, lectureID: nil, title: $0.title, body: $0.body, isPinned: $0.isPinned, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            tasks: mac.tasks.map { .init(id: $0.id, courseID: $0.courseID, title: $0.title, details: $0.details, dueDate: $0.dueDate, isCompleted: $0.completedAt != nil || ["completed", "done"].contains($0.status.lowercased()), createdAt: $0.createdAt, updatedAt: $0.updatedAt) }
        )
        try validate(pack)
        guard pack.courses.count + pack.scheduleRules.count + pack.notes.count + pack.tasks.count > 0 else { throw StudyPadTransferError.noImportableData }
        var warnings = ["NEXUS Mac v\(mac.schemaVersion) yedeğinin yalnız çalışma bölümü eşlendi; diğer modüller yok sayıldı.", "Mac notlarında ders bağlantısı bulunmadığından notlar atanmamış olarak içe aktarılacak.", "PDF ve ses dosyaları yedek JSON içinde taşınmaz."]
        if pack.notes.isEmpty { warnings.removeAll { $0.contains("Mac notlarında") } }
        return PreparedTransfer(source: .nexusMacV9, pack: pack, warnings: warnings)
    }

    private static func normalize(_ pack: StudyPadTransfer) -> StudyPadTransfer {
        StudyPadTransfer(
            format: pack.format,
            schemaVersion: StudyPadTransfer.currentVersion,
            createdAt: pack.createdAt,
            courses: pack.courses.map {
                .init(id: $0.id, name: $0.name, code: $0.code, instructor: $0.instructor, semesterWeekCount: $0.semesterWeekCount ?? 15, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            scheduleRules: pack.scheduleRules,
            lectures: pack.lectures.map {
                .init(id: $0.id, courseID: $0.courseID, title: $0.title, date: $0.date, attendance: $0.attendance, review: $0.review, note: $0.note, weekNumber: $0.weekNumber ?? 1, lessonNumber: $0.lessonNumber ?? 1, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
            },
            notes: pack.notes,
            tasks: pack.tasks
        )
    }

    static func validate(_ pack: StudyPadTransfer) throws {
        guard pack.format == StudyPadTransfer.currentFormat, pack.schemaVersion == StudyPadTransfer.currentVersion else { throw StudyPadTransferError.unsupportedVersion }
        let allIDs = pack.courses.map(\.id) + pack.scheduleRules.map(\.id) + pack.lectures.map(\.id) + pack.notes.map(\.id) + pack.tasks.map(\.id)
        guard Set(allIDs).count == allIDs.count else { throw StudyPadTransferError.duplicateIdentifiers }
        guard pack.courses.allSatisfy({ Course.validationError(name: $0.name) == nil && (1...30).contains($0.semesterWeekCount ?? 15) }) else { throw StudyPadTransferError.invalidRecord("boş ders adı veya dönem hafta sayısı") }
        guard pack.scheduleRules.allSatisfy({ CourseScheduleRule.isValid(weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes, effectiveStart: $0.effectiveStart, effectiveEnd: $0.effectiveEnd) }) else { throw StudyPadTransferError.invalidRecord("ders programı günü veya saati") }
        let courseWeeks = Dictionary(uniqueKeysWithValues: pack.courses.map { ($0.id, $0.semesterWeekCount ?? 15) })
        guard pack.lectures.allSatisfy({ value in
            let weekLimit = value.courseID.flatMap { courseWeeks[$0] } ?? 15
            return Lecture.validationError(title: value.title, courseID: value.courseID, weekNumber: value.weekNumber ?? 1, lessonNumber: value.lessonNumber ?? 1, semesterWeekCount: weekLimit) == nil
                && LectureAttendance(rawValue: value.attendance) != nil && LectureReviewStatus(rawValue: value.review) != nil
                && NoteContentPolicy.isValid(body: value.note)
        }) else { throw StudyPadTransferError.invalidRecord("oturum, hafta/ders numarası veya ders defteri") }
        guard pack.notes.allSatisfy({ StudyNote.validationError(title: $0.title) == nil && NoteContentPolicy.isValid(body: $0.body) }) else { throw StudyPadTransferError.invalidRecord("not") }
        guard pack.tasks.allSatisfy({ StudyTask.validationError(title: $0.title) == nil }) else { throw StudyPadTransferError.invalidRecord("görev") }
        let courseIDs = Set(pack.courses.map(\.id)); let lectureIDs = Set(pack.lectures.map(\.id))
        let courseReferences = pack.scheduleRules.map(\.courseID) + pack.lectures.compactMap(\.courseID) + pack.notes.compactMap(\.courseID) + pack.tasks.compactMap(\.courseID)
        guard courseReferences.allSatisfy(courseIDs.contains) else { throw StudyPadTransferError.invalidReference("pakette bulunmayan ders") }
        guard pack.notes.compactMap(\.lectureID).allSatisfy(lectureIDs.contains) else { throw StudyPadTransferError.invalidReference("pakette bulunmayan oturum") }
    }

    static func preview(_ prepared: PreparedTransfer, context: ModelContext) throws -> TransferPreview {
        let existingIDs = Set(try context.fetch(FetchDescriptor<Course>()).map(\.id)
            + context.fetch(FetchDescriptor<CourseScheduleRule>()).map(\.id)
            + context.fetch(FetchDescriptor<Lecture>()).map(\.id)
            + context.fetch(FetchDescriptor<StudyNote>()).map(\.id)
            + context.fetch(FetchDescriptor<StudyTask>()).map(\.id))
        let incoming = prepared.pack.courses.map(\.id) + prepared.pack.scheduleRules.map(\.id) + prepared.pack.lectures.map(\.id) + prepared.pack.notes.map(\.id) + prepared.pack.tasks.map(\.id)
        return TransferPreview(source: prepared.source, courseCount: prepared.pack.courses.count, scheduleCount: prepared.pack.scheduleRules.count, lectureCount: prepared.pack.lectures.count, noteCount: prepared.pack.notes.count, taskCount: prepared.pack.tasks.count, duplicateCount: incoming.filter(existingIDs.contains).count, warnings: prepared.warnings)
    }

    static func importPack(_ prepared: PreparedTransfer, policy: TransferDuplicatePolicy, context: ModelContext) throws -> TransferImportResult {
        try validate(prepared.pack)
        let courses = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Course>()).map { ($0.id, $0) })
        let schedules = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CourseScheduleRule>()).map { ($0.id, $0) })
        let lectures = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Lecture>()).map { ($0.id, $0) })
        let notes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudyNote>()).map { ($0.id, $0) })
        let tasks = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<StudyTask>()).map { ($0.id, $0) })
        var inserted = 0, updated = 0, skipped = 0
        func decision(_ exists: Bool) -> Bool { if !exists { inserted += 1; return true }; if policy == .skip { skipped += 1; return false }; updated += 1; return true }
        for value in prepared.pack.courses where decision(courses[value.id] != nil) {
            if let item = courses[value.id] { item.name = value.name; item.code = value.code; item.instructor = value.instructor; item.semesterWeekCount = value.semesterWeekCount ?? 15; item.updatedAt = value.updatedAt }
            else { context.insert(Course(id: value.id, name: value.name, code: value.code, instructor: value.instructor, semesterWeekCount: value.semesterWeekCount ?? 15, createdAt: value.createdAt, updatedAt: value.updatedAt)) }
        }
        for value in prepared.pack.scheduleRules where decision(schedules[value.id] != nil) {
            if let item = schedules[value.id] { item.courseID = value.courseID; item.weekday = value.weekday; item.startMinutes = value.startMinutes; item.durationMinutes = value.durationMinutes; item.effectiveStart = value.effectiveStart; item.effectiveEnd = value.effectiveEnd; item.location = value.location; item.isActive = value.isActive; item.updatedAt = value.updatedAt }
            else { context.insert(CourseScheduleRule(id: value.id, courseID: value.courseID, weekday: value.weekday, startMinutes: value.startMinutes, durationMinutes: value.durationMinutes, effectiveStart: value.effectiveStart, effectiveEnd: value.effectiveEnd, location: value.location, isActive: value.isActive, createdAt: value.createdAt, updatedAt: value.updatedAt)) }
        }
        for value in prepared.pack.lectures where decision(lectures[value.id] != nil) {
            if let item = lectures[value.id] { item.courseID = value.courseID; item.title = value.title; item.date = value.date; item.attendanceRaw = value.attendance; item.reviewRaw = value.review; item.note = value.note; item.weekNumber = value.weekNumber ?? 1; item.lessonNumber = value.lessonNumber ?? 1; item.updatedAt = value.updatedAt }
            else { context.insert(Lecture(id: value.id, courseID: value.courseID, title: value.title, date: value.date, attendance: LectureAttendance(rawValue: value.attendance) ?? .unmarked, reviewStatus: LectureReviewStatus(rawValue: value.review) ?? .notReviewed, note: value.note, weekNumber: value.weekNumber ?? 1, lessonNumber: value.lessonNumber ?? 1, createdAt: value.createdAt, updatedAt: value.updatedAt)) }
        }
        for value in prepared.pack.notes where decision(notes[value.id] != nil) {
            if let item = notes[value.id] { item.courseID = value.courseID; item.lectureID = value.lectureID; item.title = value.title; item.body = value.body; item.isPinned = value.isPinned; item.kind = .markdown; item.updatedAt = value.updatedAt }
            else { context.insert(StudyNote(id: value.id, courseID: value.courseID, lectureID: value.lectureID, title: value.title, body: value.body, isPinned: value.isPinned, createdAt: value.createdAt, updatedAt: value.updatedAt)) }
        }
        for value in prepared.pack.tasks where decision(tasks[value.id] != nil) {
            if let item = tasks[value.id] { item.courseID = value.courseID; item.title = value.title; item.details = value.details; item.dueDate = value.dueDate; item.isCompleted = value.isCompleted; item.updatedAt = value.updatedAt }
            else { context.insert(StudyTask(id: value.id, courseID: value.courseID, title: value.title, details: value.details, dueDate: value.dueDate, isCompleted: value.isCompleted, createdAt: value.createdAt, updatedAt: value.updatedAt)) }
        }
        do { try context.save(); return TransferImportResult(inserted: inserted, updated: updated, skipped: skipped) }
        catch { context.rollback(); throw error }
    }

    static func export(context: ModelContext) throws -> StudyPadTransfer {
        StudyPadTransfer(format: StudyPadTransfer.currentFormat, schemaVersion: StudyPadTransfer.currentVersion, createdAt: .now,
            courses: try context.fetch(FetchDescriptor<Course>()).map { .init(id: $0.id, name: $0.name, code: $0.code, instructor: $0.instructor, semesterWeekCount: $0.semesterWeekCount, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            scheduleRules: try context.fetch(FetchDescriptor<CourseScheduleRule>()).map { .init(id: $0.id, courseID: $0.courseID, weekday: $0.weekday, startMinutes: $0.startMinutes, durationMinutes: $0.durationMinutes, effectiveStart: $0.effectiveStart, effectiveEnd: $0.effectiveEnd, location: $0.location, isActive: $0.isActive, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            lectures: try context.fetch(FetchDescriptor<Lecture>()).map { .init(id: $0.id, courseID: $0.courseID, title: $0.title, date: $0.date, attendance: $0.attendanceRaw, review: $0.reviewRaw, note: $0.note, weekNumber: $0.weekNumber, lessonNumber: $0.lessonNumber, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            notes: try context.fetch(FetchDescriptor<StudyNote>()).filter { $0.kind == .markdown }.map { .init(id: $0.id, courseID: $0.courseID, lectureID: $0.lectureID, title: $0.title, body: $0.body, isPinned: $0.isPinned, createdAt: $0.createdAt, updatedAt: $0.updatedAt) },
            tasks: try context.fetch(FetchDescriptor<StudyTask>()).map { .init(id: $0.id, courseID: $0.courseID, title: $0.title, details: $0.details, dueDate: $0.dueDate, isCompleted: $0.isCompleted, createdAt: $0.createdAt, updatedAt: $0.updatedAt) })
    }
}

struct TransferJSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

enum NoteContentPolicy {
    static let maximumUTF8Bytes = 1_000_000
    static func isValid(body: String) -> Bool { body.lengthOfBytes(using: .utf8) <= maximumUTF8Bytes }
}
