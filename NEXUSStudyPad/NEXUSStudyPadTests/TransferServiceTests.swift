import XCTest
import SwiftData
@testable import NEXUSStudyPad

@MainActor
final class TransferServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)

    private func pack(courseID: UUID = UUID(), courseName: String = "Yapay Zeka") -> StudyPadTransfer {
        let lectureID = UUID()
        return StudyPadTransfer(
            format: StudyPadTransfer.currentFormat, schemaVersion: StudyPadTransfer.currentVersion, createdAt: now,
            courses: [.init(id: courseID, name: courseName, code: "AI-1", instructor: "Dr.", semesterWeekCount: 14, createdAt: now, updatedAt: now)],
            scheduleRules: [.init(id: UUID(), courseID: courseID, weekday: 2, startMinutes: 600, durationMinutes: 50, effectiveStart: now, effectiveEnd: nil, location: "A1", isActive: true, createdAt: now, updatedAt: now)],
            lectures: [.init(id: lectureID, courseID: courseID, title: "Hafta 4 ikinci ders", date: now, attendance: LectureAttendance.unmarked.rawValue, review: LectureReviewStatus.notReviewed.rawValue, note: "Ders defteri", weekNumber: 4, lessonNumber: 2, createdAt: now, updatedAt: now)],
            notes: [.init(id: UUID(), courseID: courseID, lectureID: lectureID, title: "Özet", body: "# Başlık", isPinned: false, createdAt: now, updatedAt: now)],
            tasks: [.init(id: UUID(), courseID: courseID, title: "Soruları çöz", details: "", dueDate: now, isCompleted: false, createdAt: now, updatedAt: now)])
    }

    func testNativeTransferRoundTripAndImport() throws {
        let original = pack()
        let data = try StudyPadTransferService.encoder().encode(original)
        let prepared = try StudyPadTransferService.prepare(data: data)
        XCTAssertEqual(prepared.source, .studyPadV1)
        let container = try PersistenceController.makeContainer(inMemory: true)
        let preview = try StudyPadTransferService.preview(prepared, context: container.mainContext)
        XCTAssertEqual(preview.total, 5)
        let result = try StudyPadTransferService.importPack(prepared, policy: .skip, context: container.mainContext)
        XCTAssertEqual(result, TransferImportResult(inserted: 5, updated: 0, skipped: 0))
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<CourseScheduleRule>()).count, 1)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<StudyNote>()).first?.lectureID, original.lectures.first?.id)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Course>()).first?.semesterWeekCount, 14)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Lecture>()).first?.weekNumber, 4)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Lecture>()).first?.lessonNumber, 2)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Lecture>()).first?.note, "Ders defteri")
    }

    func testV1TransferUpgradesToFifteenWeeksAndFirstLessonWithoutDataLoss() throws {
        let courseID = UUID(), lectureID = UUID()
        let old = StudyPadTransfer(
            format: StudyPadTransfer.currentFormat, schemaVersion: 1, createdAt: now,
            courses: [.init(id: courseID, name: "Eski ders", code: "", instructor: "", createdAt: now, updatedAt: now)],
            scheduleRules: [],
            lectures: [.init(id: lectureID, courseID: courseID, title: "Eski oturum", date: now, attendance: LectureAttendance.present.rawValue, review: LectureReviewStatus.reviewed.rawValue, note: "Korunacak metin", createdAt: now, updatedAt: now)],
            notes: [], tasks: []
        )
        let prepared = try StudyPadTransferService.prepare(data: StudyPadTransferService.encoder().encode(old))
        XCTAssertEqual(prepared.pack.schemaVersion, 2)
        XCTAssertEqual(prepared.pack.courses.first?.semesterWeekCount, 15)
        XCTAssertEqual(prepared.pack.lectures.first?.weekNumber, 1)
        XCTAssertEqual(prepared.pack.lectures.first?.lessonNumber, 1)
        XCTAssertEqual(prepared.pack.lectures.first?.note, "Korunacak metin")
        XCTAssertTrue(prepared.warnings.contains { $0.contains("v1") })
    }

    func testMalformedAndUnknownJSONAreRejected() {
        XCTAssertThrowsError(try StudyPadTransferService.prepare(data: Data("not json".utf8)))
        XCTAssertThrowsError(try StudyPadTransferService.prepare(data: Data("{\"schemaVersion\":42}".utf8)))
    }

    func testBrokenReferenceIsRejectedBeforeWrite() throws {
        var invalid = pack()
        invalid.tasks[0].courseID = UUID()
        let data = try StudyPadTransferService.encoder().encode(invalid)
        XCTAssertThrowsError(try StudyPadTransferService.prepare(data: data))
        let container = try PersistenceController.makeContainer(inMemory: true)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Course>()).count, 0)
    }

    func testDuplicateSkipPreservesAndUpdateChangesSameUUID() throws {
        let id = UUID(); let container = try PersistenceController.makeContainer(inMemory: true)
        container.mainContext.insert(Course(id: id, name: "Mevcut")); try container.mainContext.save()
        let prepared = try StudyPadTransferService.prepare(data: StudyPadTransferService.encoder().encode(pack(courseID: id, courseName: "Gelen")))
        let preview = try StudyPadTransferService.preview(prepared, context: container.mainContext)
        XCTAssertEqual(preview.duplicateCount, 1)
        let skipped = try StudyPadTransferService.importPack(prepared, policy: .skip, context: container.mainContext)
        XCTAssertEqual(skipped.skipped, 1); XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Course>()).first { $0.id == id }?.name, "Mevcut")
        let updated = try StudyPadTransferService.importPack(prepared, policy: .update, context: container.mainContext)
        XCTAssertGreaterThan(updated.updated, 0); XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<Course>()).first { $0.id == id }?.name, "Gelen")
    }

    func testMacV9SubsetMapsNotesUnassignedAndCompletedTask() throws {
        let courseID = UUID(), taskID = UUID(), noteID = UUID(), scheduleID = UUID()
        let iso = ISO8601DateFormatter().string(from: now)
        let json = """
        {"schemaVersion":9,"createdAt":"\(iso)","courses":[{"id":"\(courseID)","name":"Fizik","code":"F1","instructor":"Dr.","createdAt":"\(iso)","updatedAt":"\(iso)"}],"tasks":[{"id":"\(taskID)","title":"Ödev","details":"","courseID":"\(courseID)","dueDate":null,"status":"completed","completedAt":"\(iso)","createdAt":"\(iso)","updatedAt":"\(iso)"}],"notes":[{"id":"\(noteID)","title":"Mac notu","body":"İçerik","isPinned":true,"createdAt":"\(iso)","updatedAt":"\(iso)"}],"studyScheduleRules":[{"id":"\(scheduleID)","courseID":"\(courseID)","weekday":6,"startMinutes":495,"durationMinutes":90,"effectiveStart":"\(iso)","effectiveEnd":null,"locationOverride":"Lab","isActive":true,"createdAt":"\(iso)","updatedAt":"\(iso)"}],"financeEntries":[{"ignored":true}]}
        """
        let prepared = try StudyPadTransferService.prepare(data: Data(json.utf8))
        XCTAssertEqual(prepared.source, .nexusMacV9)
        XCTAssertNil(prepared.pack.notes.first?.courseID)
        XCTAssertTrue(try XCTUnwrap(prepared.pack.tasks.first).isCompleted)
        XCTAssertEqual(prepared.pack.scheduleRules.first?.startMinutes, 495)
    }

    func testExportExcludesDocumentsAudioAndHandwritingBinary() throws {
        let container = try PersistenceController.makeContainer(inMemory: true); let context = container.mainContext
        context.insert(StudyDocument(title: "PDF", storedFileName: "x.pdf"))
        context.insert(AudioRecording(lectureID: UUID(), title: "Ses", storedFileName: "x.m4a", durationSeconds: 2))
        context.insert(StudyNote(title: "El", kind: .handwritten, drawingData: Data([1])))
        context.insert(StudyNote(title: "Metin", body: "Güvenli"))
        try context.save()
        let exported = try StudyPadTransferService.export(context: context)
        XCTAssertEqual(exported.notes.map(\.title), ["Metin"])
        let json = String(decoding: try StudyPadTransferService.encoder().encode(exported), as: UTF8.self)
        XCTAssertFalse(json.contains("x.pdf")); XCTAssertFalse(json.contains("x.m4a"))
    }
}
