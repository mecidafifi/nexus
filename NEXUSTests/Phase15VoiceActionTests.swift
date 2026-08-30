import XCTest
import SwiftData
@testable import NEXUS

@MainActor
final class Phase15VoiceActionTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        value.firstWeekday = 2
        return value
    }

    private func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    func testTurkishQuickEntryBecomesInertVoiceDraft() throws {
        let result = LocalVoiceActionParser.parse("Yarın saat 17'de Fizik ödevi çalışma görevi, 45 dakika", referenceDate: date(1, hour: 9), calendar: calendar)
        guard case .draft(let draft) = result else { return XCTFail("Taslak bekleniyordu") }
        XCTAssertEqual(draft.kind, .studyTask)
        XCTAssertEqual(draft.title, "Fizik ödevi")
        XCTAssertEqual(draft.dueDate, date(2, hour: 17))
        XCTAssertEqual(draft.durationMinutes, 45)
        XCTAssertEqual(draft.interpretationSource, .local)
    }

    func testArabicTomorrowLessonParsesLocallyWithoutGuessing() {
        let result = LocalVoiceActionParser.parse("بكرا الساعة خمسة عندي درس الذكاء الاصطناعي", referenceDate: date(1, hour: 9), calendar: calendar)
        guard case .draft(let draft) = result else { return XCTFail("Arapça taslak bekleniyordu") }
        XCTAssertEqual(draft.kind, .weeklyLesson)
        XCTAssertEqual(draft.title, "الذكاء الاصطناعي")
        XCTAssertEqual(draft.startDate, date(2, hour: 5))
        XCTAssertEqual(draft.recurrenceEnd, calendar.startOfDay(for: date(2)))
    }

    func testArabicGymWithoutDateAndTimeClarifiesAndNeverCreatesDraft() {
        let result = LocalVoiceActionParser.parse("آخر الأسبوع حط نادي", referenceDate: date(1), calendar: calendar)
        guard case .clarification(let question) = result else { return XCTFail("Açıklama sorusu bekleniyordu") }
        XCTAssertTrue(question.contains("يرجى"))
    }

    func testArabicStudyTaskAndFinanceExpenseUseIndependentKinds() {
        guard case .draft(let task) = LocalVoiceActionParser.parse("أضف واجب تقرير بكرا الساعة خمسة", referenceDate: date(1), calendar: calendar),
              case .draft(let expense) = LocalVoiceActionParser.parse("أضف مصروف 50 ليرة قهوة", referenceDate: date(1), calendar: calendar) else { return XCTFail() }
        XCTAssertEqual(task.kind, .studyTask)
        XCTAssertEqual(task.dueDate, date(2, hour: 5))
        XCTAssertEqual(expense.kind, .financeExpense)
        XCTAssertEqual(expense.amountMinorUnits, 5_000)
    }

    func testTurkishAndArabicVoiceConfirmCancelUndoControls() {
        XCTAssertEqual(VoiceActionSpeechControl.parse("Onayla"), .confirm)
        XCTAssertEqual(VoiceActionSpeechControl.parse("Evet"), .confirm)
        XCTAssertEqual(VoiceActionSpeechControl.parse("تأكيد"), .confirm)
        XCTAssertEqual(VoiceActionSpeechControl.parse("نعم"), .confirm)
        XCTAssertEqual(VoiceActionSpeechControl.parse("İptal"), .cancel)
        XCTAssertEqual(VoiceActionSpeechControl.parse("إلغاء"), .cancel)
        XCTAssertEqual(VoiceActionSpeechControl.parse("geri al"), .undo)
    }

    func testVoiceCorrectionsOnlyChangeTransientDraft() {
        let original = VoiceActionDraft(kind: .calendarEvent, title: "Görüşme", startDate: date(2, hour: 10), endDate: date(2, hour: 11), durationMinutes: 60, originalText: "")
        let renamed = LocalVoiceActionParser.applying(.title("Danışman görüşmesi"), to: original, calendar: calendar)
        let retimed = LocalVoiceActionParser.applying(.time(hour: 15, minute: 30), to: renamed, calendar: calendar)
        XCTAssertEqual(retimed.title, "Danışman görüşmesi")
        XCTAssertEqual(retimed.startDate, date(2, hour: 15, minute: 30))
        XCTAssertEqual(retimed.endDate, date(2, hour: 16, minute: 30))
        XCTAssertEqual(original.title, "Görüşme")
    }

    func testPrepareAndPreviewNeverWrite() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let draft = VoiceActionDraft(kind: .studyTask, title: "TEST — Taslak", dueDate: date(2, hour: 17), durationMinutes: 45, originalText: "")
        let prepared = try VoiceActionPersistenceService.prepare(draft, context: container.mainContext, calendar: calendar)
        XCTAssertEqual(prepared.0.exactFieldLines.first, "İşlem: Yeni kayıt")
        XCTAssertTrue(try container.mainContext.fetch(FetchDescriptor<StudyTask>()).isEmpty)
    }

    func testAllInitialCreateKindsRouteOnlyToIndependentModels() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let project = VoiceActionDraft(kind: .organizationProject, title: "TEST — Proje", durationMinutes: 0, originalText: "")
        _ = try VoiceActionPersistenceService.confirm(project, context: context, calendar: calendar, now: date(1))
        let drafts: [VoiceActionDraft] = [
            .init(kind: .studyTask, title: "TEST — Ödev", dueDate: date(2, hour: 17), durationMinutes: 45, originalText: ""),
            .init(kind: .studyCourse, title: "TEST — Ders", durationMinutes: 0, originalText: ""),
            .init(kind: .weeklyLesson, title: "TEST — Haftalık", startDate: date(7, hour: 9), endDate: date(7, hour: 9, minute: 50), weekday: 2, durationMinutes: 50, recurrenceEnd: date(28), originalText: ""),
            .init(kind: .organizationTask, title: "TEST — Org görev", dueDate: date(3, hour: 18), durationMinutes: 30, projectName: "TEST — Proje", originalText: ""),
            .init(kind: .calendarEvent, title: "TEST — Etkinlik", startDate: date(4, hour: 9), endDate: date(4, hour: 10), durationMinutes: 60, originalText: ""),
            .init(kind: .calendarTask, title: "TEST — Takvim görev", startDate: date(4, hour: 11), endDate: date(4, hour: 11, minute: 30), durationMinutes: 30, originalText: ""),
            .init(kind: .calendarReminder, title: "TEST — Hatırlatma", startDate: date(4, hour: 12), endDate: date(4, hour: 12), durationMinutes: 0, originalText: ""),
            .init(kind: .gymSession, title: "TEST — Spor", startDate: date(4, hour: 14), endDate: date(4, hour: 15), durationMinutes: 60, originalText: ""),
            .init(kind: .financeExpense, title: "TEST — Gider", startDate: date(4, hour: 16), durationMinutes: 0, amountMinorUnits: 2_500, originalText: ""),
            .init(kind: .financeIncome, title: "TEST — Gelir", startDate: date(4, hour: 17), durationMinutes: 0, amountMinorUnits: 10_000, originalText: ""),
            .init(kind: .note, title: "TEST — Not", details: "Gövde", durationMinutes: 0, originalText: "")
        ]
        for draft in drafts { _ = try VoiceActionPersistenceService.confirm(draft, context: context, calendar: calendar, now: date(1)) }
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyTask>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Course>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<StudyScheduleRule>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<OrganizationTask>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CalendarEntry>()).map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.event, .reminder, .task])
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlannedWorkoutSession>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<FinanceEntry>()).count, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<NexusNote>()).count, 1)
    }

    func testDuplicateIsRejectedWithoutSecondWrite() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let draft = VoiceActionDraft(kind: .studyTask, title: "TEST — Aynı", dueDate: date(2, hour: 17), durationMinutes: 45, originalText: "")
        _ = try VoiceActionPersistenceService.confirm(draft, context: container.mainContext, calendar: calendar)
        XCTAssertThrowsError(try VoiceActionPersistenceService.confirm(draft, context: container.mainContext, calendar: calendar))
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<StudyTask>()).count, 1)
    }

    func testConflictRequiresExplicitKeepOrRescheduleBeforeConfirmation() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(CalendarEntry(title: "Sabit", startDate: date(4, hour: 10), endDate: date(4, hour: 11)))
        try context.save()
        let draft = VoiceActionDraft(kind: .calendarEvent, title: "Çakışan", startDate: date(4, hour: 10, minute: 30), endDate: date(4, hour: 11, minute: 30), durationMinutes: 60, originalText: "")
        let result = try VoiceActionPersistenceService.prepare(draft, context: context, calendar: calendar)
        guard case .conflict(let conflict) = result.1 else { return XCTFail("Çakışma bekleniyordu") }
        XCTAssertNotNil(conflict.suggestedStart)
        XCTAssertThrowsError(try VoiceActionPersistenceService.confirm(draft, context: context, calendar: calendar))
        XCTAssertEqual(try context.fetch(FetchDescriptor<CalendarEntry>()).count, 1)
        let moved = VoiceActionPersistenceService.rescheduled(draft, to: conflict.suggestedStart!, calendar: calendar)
        _ = try VoiceActionPersistenceService.confirm(moved, context: context, calendar: calendar)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CalendarEntry>()).count, 2)
    }

    func testCreateUndoDeletesOnlyCreatedSourceRecord() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let existing = NexusNote(title: "Kullanıcı notu")
        container.mainContext.insert(existing)
        try container.mainContext.save()
        let token = try VoiceActionPersistenceService.confirm(.init(kind: .note, title: "TEST — Sesli", durationMinutes: 0, originalText: ""), context: container.mainContext)
        try VoiceActionPersistenceService.undo(token, context: container.mainContext)
        let notes = try container.mainContext.fetch(FetchDescriptor<NexusNote>())
        XCTAssertEqual(notes.map(\.title), ["Kullanıcı notu"])
    }

    func testEditAndUndoUseUniqueTargetAndPreserveOtherRecords() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let first = StudyTask(title: "TEST — Taşınacak", dueDate: date(2, hour: 17))
        let other = StudyTask(title: "Kullanıcı görevi", dueDate: date(3, hour: 10))
        container.mainContext.insert(first); container.mainContext.insert(other); try container.mainContext.save()
        let draft = VoiceActionDraft(verb: .edit, kind: .studyTask, title: first.title, dueDate: date(5, hour: 17), durationMinutes: 60, targetOriginalTitle: first.title, originalText: "")
        let token = try VoiceActionPersistenceService.confirm(draft, context: container.mainContext, calendar: calendar)
        XCTAssertEqual(first.dueDate, date(5, hour: 17)); XCTAssertEqual(other.dueDate, date(3, hour: 10))
        try VoiceActionPersistenceService.undo(token, context: container.mainContext)
        XCTAssertEqual(first.dueDate, date(2, hour: 17)); XCTAssertEqual(other.dueDate, date(3, hour: 10))
    }

    func testAmbiguousEditTargetDoesNotWrite() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let first = StudyTask(title: "Aynı", dueDate: date(2)); let second = StudyTask(title: "Aynı", dueDate: date(3))
        container.mainContext.insert(first); container.mainContext.insert(second); try container.mainContext.save()
        let draft = VoiceActionDraft(verb: .edit, kind: .studyTask, title: "Aynı", dueDate: date(9), durationMinutes: 60, targetOriginalTitle: "Aynı", originalText: "")
        XCTAssertThrowsError(try VoiceActionPersistenceService.confirm(draft, context: container.mainContext, calendar: calendar))
        XCTAssertEqual(first.dueDate, date(2)); XCTAssertEqual(second.dueDate, date(3))
    }

    func testCancelAndUndoUseRealTaskCancelledStatus() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let task = StudyTask(title: "TEST — İptal", dueDate: date(2), status: .planned)
        container.mainContext.insert(task); try container.mainContext.save()
        let draft = VoiceActionDraft(verb: .cancel, kind: .studyTask, title: task.title, durationMinutes: 0, targetOriginalTitle: task.title, originalText: "")
        let token = try VoiceActionPersistenceService.confirm(draft, context: container.mainContext)
        XCTAssertEqual(task.status, .cancelled)
        try VoiceActionPersistenceService.undo(token, context: container.mainContext)
        XCTAssertEqual(task.status, .planned)
    }

    func testCoordinatorDoesNotWriteUntilTurkishOrArabicVoiceConfirmation() async throws {
        let harness = try makeHarness()
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        await harness.coordinator.processText("Yarın saat 17'de TEST — Sesli çalışma görevi, 45 dakika")
        XCTAssertNotNil(harness.coordinator.pendingAction)
        XCTAssertTrue(try harness.context.fetch(FetchDescriptor<StudyTask>()).isEmpty)
        await harness.coordinator.processText("نعم")
        XCTAssertNil(harness.coordinator.pendingAction)
        XCTAssertEqual(try harness.context.fetch(FetchDescriptor<StudyTask>()).count, 1)
    }

    func testCoordinatorClarificationAndCancelNeverWrite() async throws {
        let harness = try makeHarness()
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        await harness.coordinator.processText("آخر الأسبوع حط نادي")
        XCTAssertNil(harness.coordinator.pendingAction)
        await harness.coordinator.processText("Yarın saat 17'de TEST — İptal çalışma görevi")
        XCTAssertNotNil(harness.coordinator.pendingAction)
        await harness.coordinator.processText("إلغاء")
        XCTAssertNil(harness.coordinator.pendingAction)
        XCTAssertTrue(try harness.context.fetch(FetchDescriptor<StudyTask>()).isEmpty)
    }

    func testRemoteDraftInterpretationRequiresExactOneTimeConsent() async throws {
        let remoteDraft = FakeDraftInterpreter(result: .init(kind: .studyCourse, title: "TEST — Uzak taslak", durationMinutes: 0, originalText: "", interpretationSource: .remote))
        let harness = try makeHarness(key: "sk-test-123456789012345678901234", remoteDraft: remoteDraft)
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { true })
        await harness.coordinator.processText("Bu kaydı değiştir")
        XCTAssertEqual(harness.coordinator.pendingDraftInterpretationConsent?.exactOutgoingText, "Bu kaydı değiştir")
        let callsBefore = await remoteDraft.callCount
        XCTAssertEqual(callsBefore, 0)
        XCTAssertTrue(try harness.context.fetch(FetchDescriptor<Course>()).isEmpty)
        await harness.coordinator.approveDraftInterpretationConsentNow()
        let callsAfter = await remoteDraft.callCount
        XCTAssertEqual(callsAfter, 1)
        XCTAssertNotNil(harness.coordinator.pendingAction)
        XCTAssertTrue(try harness.context.fetch(FetchDescriptor<Course>()).isEmpty)
    }

    func testRemoteDraftRequestIsStatelessAndExposesOnlyInertProposalFunction() throws {
        let data = try VoiceRemoteDraftRequestBuilder.makeBody(text: "Yarın görev ekle", model: "test-model")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["parallel_tool_calls"] as? Bool, false)
        XCTAssertEqual(body["input"] as? String, "Yarın görev ekle")
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        XCTAssertEqual(tools.count, 1)
        XCTAssertEqual(tools[0]["name"] as? String, "propose_nexus_action")
        XCTAssertEqual(tools[0]["strict"] as? Bool, true)
        XCTAssertNil(tools[0]["execute"])
        let choice = try XCTUnwrap(body["tool_choice"] as? [String: Any])
        XCTAssertEqual(choice["name"] as? String, "propose_nexus_action")
    }

    func testLockBlocksDraftAndConfirmation() async throws {
        let harness = try makeHarness()
        harness.coordinator.configure(context: harness.context, navigation: { _ in }, accessAllowed: { false })
        await harness.coordinator.processText("Yarın saat 17'de TEST — Kilit çalışma görevi")
        XCTAssertNil(harness.coordinator.pendingAction)
        XCTAssertTrue(try harness.context.fetch(FetchDescriptor<StudyTask>()).isEmpty)
    }

    func testArabicWakePhraseNormalizationPreservesArabicLetters() {
        XCTAssertTrue(WakePhraseMatcher.isValid("مرحبا يا مساعد"))
        let result = WakePhraseMatcher.match(transcript: "مرحبا يا مساعد أضف واجب", phrase: "مرحبا يا مساعد")
        XCTAssertTrue(result.matched)
        XCTAssertEqual(result.remainder, "أضف واجب")
    }

    func testBackupRemainsV9AndExcludesTransientVoiceActionState() throws {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let backup = try BackupService.export(from: container.mainContext)
        let json = String(decoding: try JSONEncoder().encode(backup), as: UTF8.self)
        XCTAssertEqual(backup.schemaVersion, 9)
        XCTAssertFalse(json.contains("pendingAction"))
        XCTAssertFalse(json.contains("interpretationSource"))
        XCTAssertFalse(json.contains("openai-api-key"))
    }

    private func makeHarness(key: String? = nil, remoteDraft: FakeDraftInterpreter = FakeDraftInterpreter()) throws -> Phase15Harness {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let suite = "NEXUS.Phase15Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!; defaults.removePersistentDomain(forName: suite)
        let coordinator = VoiceAssistantCoordinator(permissions: Phase15Permissions(), recognizer: Phase15Recognizer(), speaker: Phase15Speaker(), secureStore: Phase15Store(value: key), remote: Phase15Remote(), remoteDraftInterpreter: remoteDraft, defaults: defaults)
        return .init(container: container, coordinator: coordinator)
    }
}

@MainActor private struct Phase15Harness { let container: ModelContainer; let coordinator: VoiceAssistantCoordinator; var context: ModelContext { container.mainContext } }
private final class Phase15Permissions: VoicePermissionProviding {
    var microphoneState: VoicePermissionState = .notDetermined; var speechState: VoicePermissionState = .notDetermined
    func requestMicrophone() async -> VoicePermissionState { .denied }; func requestSpeech() async -> VoicePermissionState { .denied }
}
private final class Phase15Recognizer: VoiceSpeechRecognizing {
    func supportsOnDeviceRecognition(localeIdentifier: String) -> Bool { true }
    func start(localeIdentifier: String, onTranscript: @escaping (String, Bool) -> Void, onError: @escaping (Error) -> Void) throws {}
    func stop() {}
}
private final class Phase15Speaker: VoiceSpeaking { func speak(_ text: String, completion: @escaping () -> Void) {}; func stop() {} }
private final class Phase15Store: SecureStringStore {
    var value: String?; init(value: String?) { self.value = value }
    func read() throws -> String? { value }; func write(_ value: String) throws { self.value = value }; func delete() throws { value = nil }
}
private actor Phase15Remote: VoiceRemoteAnswering {
    func testConnection(apiKey: String) async throws {}
    func answer(question: String, groundedContext: String?, model: String, apiKey: String) async throws -> String { "Yanıt" }
}
private actor FakeDraftInterpreter: VoiceRemoteDraftInterpreting {
    private(set) var callCount = 0
    let result: VoiceActionDraft
    init(result: VoiceActionDraft = .init(kind: .note, title: "Taslak", durationMinutes: 0, originalText: "", interpretationSource: .remote)) { self.result = result }
    func proposeAction(text: String, model: String, apiKey: String) async throws -> VoiceActionDraft { callCount += 1; return result }
}
